#!/usr/bin/env bash
# =============================================================================
#  02-pruebas-balanceo.sh
#  Laboratorio 5 - Validación del balanceo de carga y de la tolerancia a fallos
#
#  Ejecuta, en este orden:
#    FASE 1: 3 réplicas, 12 POST /api/ordenes -> los atienden las 3 instancias.
#    FASE 2: se CAE 1 instancia (sin auto-reinicio), 10 POST -> las 2 restantes.
#    FASE 3: se CAE otra instancia, 8 POST -> la única instancia que queda.
#    FASE 4: se restaura el auto-reinicio -> Swarm recupera las 3 (auto-healing).
#
#  ¿Por qué se desactiva el auto-reinicio en las fases 2 y 3?
#  El compose define `restart_policy: any` para dar alta disponibilidad: si una
#  tarea se cae, Swarm la re-crea en pocos segundos. Para poder validar lo que
#  pide el laboratorio ("las otras 2 siguen atendiendo" y "la única que queda
#  sigue atendiendo") hay que simular una caída SOSTENIDA, es decir que la
#  instancia no vuelva. Por eso el script, sólo durante la prueba:
#      docker service update --restart-condition none tienda_lab5_api
#  y al terminar (o si algo falla) restaura la política original:
#      docker service update --restart-condition any  tienda_lab5_api
#  Ojo: cambiar la política dispara un rolling update; el script espera a que
#  termine (UpdateStatus=completed) antes de matar la instancia, para que no
#  haya tareas nuevas "Starting" mezcladas con las que se están probando.
#
#  Para cada fase guarda en ../resultados/:
#    - faseN-logs.txt          logs crudos del servicio (con el prefijo de réplica)
#    - faseN-tareas.txt        `docker service ps` de la fase
#    - respuestas-<fecha>.csv  una línea por request (HTTP, orden, X-Instancia)
#    - resumen-<fecha>.txt     resumen consolidado de la ejecución
#
#  Uso:
#      bash scripts/02-pruebas-balanceo.sh
#      API_PORT=18080 bash scripts/02-pruebas-balanceo.sh     # si el 8080 está ocupado
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

RESULTADOS="$SCRIPT_DIR/../resultados"
mkdir -p "$RESULTADOS"

FECHA="$(date +%Y%m%d-%H%M%S)"
CSV="$RESULTADOS/respuestas-$FECHA.csv"
RESUMEN="$RESULTADOS/resumen-$FECHA.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf 'estado;http;orden;instancia;etiqueta\n' > "$CSV"

# --- Contadores globales -----------------------------------------------------
REQUEST_NUM=0
OK=0
FALLIDOS=0
FALLOS_ASERCION=0
PRODUCTO_ID=""
ULTIMA_ORDEN=""
AUTO_REINICIO_DESACTIVADO=0

fecha_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# -----------------------------------------------------------------------------
# Precondiciones
# -----------------------------------------------------------------------------
titulo "Verificando el cluster"
verificar_docker
if [ "$(estado_swarm)" != "active" ]; then
  log_error "El nodo no está en modo Swarm. Ejecutá primero: bash scripts/01-levantar-cluster.sh"
  exit 1
fi
if ! docker service inspect "$API_SERVICE" >/dev/null 2>&1; then
  log_error "No existe el servicio '$API_SERVICE'. Ejecutá primero: bash scripts/01-levantar-cluster.sh"
  exit 1
fi
log_ok "Servicio '$API_SERVICE' encontrado."
docker node ls

# Contexto para el informe
{
  echo "=============================================================="
  echo " Laboratorio 5 - Resumen de la ejecución"
  echo " Fecha: $(date)"
  echo " Host:  $(hostname)"
  echo " Docker: $(docker version --format '{{.Server.Version}}')"
  echo " Stack:  $STACK"
  echo " API:    $API_URL"
  echo "=============================================================="
  echo
  echo "--- Nodos del swarm ---"
  docker node ls
  echo
} > "$RESUMEN"

# -----------------------------------------------------------------------------
# Producto de prueba (las órdenes necesitan un producto existente)
# -----------------------------------------------------------------------------
titulo "Preparando datos de prueba"
crear_producto() {
  local archivo="$TMP/producto.json" codigo id
  codigo=$(curl -sS --max-time 20 -o "$archivo" -w '%{http_code}' \
    -X POST "$API_URL/api/productos" \
    -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Producto Laboratorio 5 $FECHA\",\"descripcion\":\"Producto de prueba para validar el balanceo\",\"precio\":100.00,\"stock\":100000,\"categoria\":\"Pruebas\",\"imagenes\":[]}" \
    || echo "000")
  if [ "$codigo" != "201" ]; then
    log_error "No se pudo crear el producto de prueba (HTTP $codigo)."
    head -c 300 "$archivo" >&2 2>/dev/null || true
    exit 1
  fi
  id=$(grep -o '"id":[[:space:]]*[0-9][0-9]*' "$archivo" | head -n 1 | grep -o '[0-9][0-9]*' || true)
  if [ -z "$id" ]; then
    log_error "No se pudo obtener el id del producto creado."
    cat "$archivo" >&2
    exit 1
  fi
  printf '%s\n' "$id"
}

PRODUCTO_ID="$(crear_producto)"
if [ -z "$PRODUCTO_ID" ]; then
  log_error "No se pudo crear el producto de prueba; se aborta la ejecución."
  exit 1
fi
log_ok "Producto de prueba creado: id=$PRODUCTO_ID"

# -----------------------------------------------------------------------------
# Helpers de la prueba
# -----------------------------------------------------------------------------

# Estado del último update del servicio (updating / completed / paused / ...).
estado_update() {
  docker service inspect --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}' "$API_SERVICE" 2>/dev/null || true
}

# Espera a que el rolling update del servicio termine.
esperar_update_completado() {
  local timeout="${1:-240}" inicio e
  inicio=$(date +%s)
  while :; do
    e="$(estado_update)"
    if [ "$e" = "completed" ]; then
      log_ok "El update del servicio terminó (todas las tareas al día)."
      return 0
    fi
    if [ $(( $(date +%s) - inicio )) -ge "$timeout" ]; then
      log_warn "El update no terminó en ${timeout}s (estado: ${e:-desconocido})."
      return 1
    fi
    sleep 3
  done
}

# Desactiva el auto-reinicio de Swarm (sólo para la prueba de caída sostenida).
desactivar_autoreinicio() {
  local cond
  if [ "${AUTO_REINICIO_DESACTIVADO:-0}" = "1" ]; then
    return 0
  fi
  cond=$(docker service inspect --format '{{.Spec.TaskTemplate.RestartPolicy.Condition}}' "$API_SERVICE")
  if [ "$cond" = "none" ]; then
    AUTO_REINICIO_DESACTIVADO=1
    return 0
  fi
  log_info "Desactivando el auto-reinicio (restart_policy=none) para simular caídas que NO se reparan solas..."
  docker service update --restart-condition none "$API_SERVICE" >/dev/null
  AUTO_REINICIO_DESACTIVADO=1
  esperar_update_completado 240 || FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
  esperar_replicas "$API_SERVICE" 3 240 || FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
  log_ok "Auto-reinicio desactivado: las instancias que se caigan no se reponen."
}

# Restaura la política original del compose (auto-reparación / alta disponibilidad).
reactivar_autoreinicio() {
  if [ "${AUTO_REINICIO_DESACTIVADO:-0}" != "1" ]; then
    return 0
  fi
  AUTO_REINICIO_DESACTIVADO=0
  log_info "Restaurando el auto-reinicio (restart_policy=any)..."
  if ! docker service update --restart-condition any "$API_SERVICE" >/dev/null 2>&1; then
    log_warn "No se pudo restaurar restart_policy=any."
    return 1
  fi
  esperar_update_completado 240 || true
  esperar_replicas "$API_SERVICE" 3 300 || true
  log_ok "Auto-reinicio restaurado."
}

# Baja UNA instancia (contenedor) y verifica que quede N/3 estable, sin auto-repararse.
matar_instancia() {
  local esperadas="$1" victima nombre corriendo
  victima=$(docker ps -q --filter "label=com.docker.swarm.service.name=$API_SERVICE" | head -n 1)
  if [ -z "$victima" ]; then
    log_error "No hay contenedores de '$API_SERVICE' para bajar."
    FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
    return 1
  fi
  nombre=$(docker inspect --format '{{.Name}}' "$victima" 2>/dev/null || echo "$victima")
  log_info "Bajando la instancia $nombre (docker kill)..."
  docker kill "$victima" >/dev/null || true

  log_info "Esperando a que el servicio quede en $esperadas/3 réplicas (sin reponer la caída)..."
  esperar_replicas "$API_SERVICE" "$esperadas" 120 || FALLOS_ASERCION=$((FALLOS_ASERCION + 1))

  # Re-chequeo después de unos segundos: si el auto-reinicio estuviera activo,
  # Swarm ya habría creado una tarea nueva y esto fallaría.
  sleep 10
  corriendo=$(replicas_corriendo "$API_SERVICE")
  if [ "$corriendo" -ne "$esperadas" ]; then
    log_error "Se esperaban $esperadas réplicas estables y hay $corriendo (¿se auto-reparó?)."
    FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
    return 1
  fi
  log_ok "Caída sostenida: $corriendo/3 réplicas corriendo (la instancia no volvió)."
  return 0
}

# Hace un POST /api/ordenes y registra el resultado (HTTP + header X-Instancia).
hacer_pedido() {
  local etiqueta="$1"
  local archivo="$TMP/orden-$etiqueta.json" cabeceras="$TMP/orden-$etiqueta.txt"
  local codigo instancia id cuerpo

  cuerpo="{\"email\":\"${etiqueta}@laboratorio5.uy\",\"direccionEnvio\":\"Av. Italia 2400\",\"telefono\":\"099123456\",\"productos\":[{\"productoId\":${PRODUCTO_ID},\"cantidad\":1}]}"

  codigo=$(curl -sS --max-time 30 -o "$archivo" -D "$cabeceras" -w '%{http_code}' \
    -X POST "$API_URL/api/ordenes" \
    -H 'Content-Type: application/json' \
    -d "$cuerpo" || echo "000")

  instancia=$(grep -i '^x-instancia:' "$cabeceras" 2>/dev/null | tr -d '\r' | awk '{print $2}' || true)
  # El primer "id" del JSON de la orden es el de la orden (el de los productos va anidado después).
  id=$(grep -o '"id":[[:space:]]*[0-9][0-9]*' "$archivo" 2>/dev/null | head -n 1 | grep -o '[0-9][0-9]*' || true)
  REQUEST_NUM=$((REQUEST_NUM + 1))

  if [ "$codigo" = "201" ]; then
    OK=$((OK + 1))
    printf '%s\n' "OK;${codigo};${id:-};${instancia:-};${etiqueta}" >> "$CSV"
    printf '   [%02d] POST /api/ordenes -> %sHTTP %s%s | orden #%s | atendida por instancia=%s\n' \
      "$REQUEST_NUM" "$C_VERDE" "$codigo" "$C_NC" "${id:-?}" "${instancia:-?}"
    ULTIMA_ORDEN="$id"
    return 0
  fi

  FALLIDOS=$((FALLIDOS + 1))
  printf '%s\n' "FALLO;${codigo};${id:-};${instancia:-};${etiqueta}" >> "$CSV"
  printf '   [%02d] POST /api/ordenes -> %sHTTP %s%s | respuesta: %s\n' \
    "$REQUEST_NUM" "$C_ROJO" "$codigo" "$C_NC" "$(head -c 160 "$archivo" 2>/dev/null | tr '\n' ' ')"
  return 1
}

capturar_logs() {
  local desde="$1" destino="$2"
  docker service logs --timestamps --since "$desde" "$API_SERVICE" > "$destino" 2>&1 || true
}

guardar_tareas() {
  local destino="$1"
  docker service ps --format '{{.Name}} | {{.CurrentState}} | desired={{.DesiredState}} | nodo={{.Node}} | error={{.Error}}' \
    "$API_SERVICE" > "$destino" 2>&1 || true
}

# Imprime y valida la distribución de requests de una fase.
validar_fase() {
  local numero="$1" esperadas="$2" pedidos="$3"
  local archivo="$RESULTADOS/fase$numero-logs.txt"
  local registrados distintas detalle replicas

  registrados="$(contar_requests "$archivo")"
  detalle="$(contar_por_instancia "$archivo")"
  distintas=$(printf '%s\n' "$detalle" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
  replicas=$(docker service ls --filter "name=$API_SERVICE" --format '{{.Replicas}}' 2>/dev/null || true)

  echo
  echo "   Requests registrados en los logs del servicio : $registrados (esperados: $pedidos)"
  echo "   Instancias distintas que los atendieron       : $distintas (esperadas: $esperadas)"
  echo "   Estado del servicio                           : ${replicas:-?} (esperado: $esperadas/3)"
  if [ -n "$detalle" ]; then
    echo "   Distribución por instancia:"
    printf '%s\n' "$detalle" | sed 's/^/      /'
  else
    echo "   (no se encontraron líneas [REQ] POST /api/ordenes en los logs)"
  fi

  {
    echo "--- FASE $numero (se esperaban $esperadas instancias, $pedidos requests y $esperadas/3 réplicas) ---"
    echo "Requests en logs: $registrados | instancias distintas: $distintas | servicio: ${replicas:-?}"
    printf '%s\n' "$detalle"
    echo
  } >> "$RESUMEN"

  if [ "$distintas" -ne "$esperadas" ] || [ "$registrados" -ne "$pedidos" ]; then
    log_error "La FASE $numero no cumple lo esperado (instancias: $distintas/$esperadas, requests: $registrados/$pedidos)."
    FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
    return 1
  fi
  if [ "$replicas" != "${esperadas}/3" ]; then
    log_error "La FASE $numero no cumple lo esperado (servicio: ${replicas:-?}, esperado: ${esperadas}/3)."
    FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
    return 1
  fi
  log_ok "FASE $numero validada: $pedidos requests repartidos entre $esperadas instancia(s) y el servicio quedó en ${replicas}."
  return 0
}

# Ejecuta una fase de caída: baja una instancia, hace N pedidos y valida.
ejecutar_fase_caida() {
  local numero="$1" titulo_fase="$2" pedidos="$3" esperadas="$4"
  local inicio i

  titulo "FASE $numero - $titulo_fase"
  if [ "$numero" -eq 2 ]; then
    desactivar_autoreinicio || true
  fi
  matar_instancia "$esperadas" || true

  guardar_tareas "$RESULTADOS/fase$numero-tareas.txt"
  docker service ps --format '   tarea: {{.Name}} | {{.CurrentState}} | desired={{.DesiredState}}' "$API_SERVICE" | head -n 8 || true

  # La ventana de logs arranca después de la caída y la estabilización.
  sleep 1
  inicio="$(fecha_utc)"
  echo
  log_info "Enviando $pedidos POST /api/ordenes por el puerto publicado (balanceador)..."
  for i in $(seq 1 "$pedidos"); do
    hacer_pedido "f${numero}-$(printf '%02d' "$i")" || true
    sleep 0.3
  done

  log_info "Esperando el volcado de logs..."
  sleep 3
  capturar_logs "$inicio" "$RESULTADOS/fase$numero-logs.txt"
  validar_fase "$numero" "$esperadas" "$pedidos" || true
}

# Si el script se corta (error, Ctrl+C), deja el servicio como estaba.
trap 'reactivar_autoreinicio >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

# -----------------------------------------------------------------------------
# FASE 1: 3 réplicas
# -----------------------------------------------------------------------------
titulo "FASE 1 - 3 réplicas - las solicitudes se reparten entre los 3 nodos"
guardar_tareas "$RESULTADOS/fase1-tareas.txt"
docker service ps --format '   tarea: {{.Name}} | {{.CurrentState}} | desired={{.DesiredState}}' "$API_SERVICE" | head -n 8 || true
sleep 1
inicio="$(fecha_utc)"
echo
log_info "Enviando 12 POST /api/ordenes por el puerto publicado (balanceador)..."
for i in $(seq 1 12); do
  hacer_pedido "f1-$(printf '%02d' "$i")" || true
  sleep 0.3
done
log_info "Esperando el volcado de logs..."
sleep 3
capturar_logs "$inicio" "$RESULTADOS/fase1-logs.txt"
validar_fase 1 3 12 || true

# -----------------------------------------------------------------------------
# FASE 2: se cae 1 instancia -> quedan 2 (sin auto-reinicio)
# -----------------------------------------------------------------------------
ejecutar_fase_caida 2 "se cae 1 instancia - las otras 2 siguen procesando" 10 2

# -----------------------------------------------------------------------------
# FASE 3: se cae otra instancia -> queda 1
# -----------------------------------------------------------------------------
ejecutar_fase_caida 3 "se cae otra instancia - la única viva sigue procesando" 8 1

# -----------------------------------------------------------------------------
# FASE 4: se restaura el auto-reinicio y Swarm recupera las 3
# -----------------------------------------------------------------------------
titulo "FASE 4 - Se restaura el auto-reinicio: Swarm recupera las 3 instancias"
reactivar_autoreinicio
guardar_tareas "$RESULTADOS/fase4-tareas.txt"
docker service ps --format '   tarea: {{.Name}} | {{.CurrentState}} | desired={{.DesiredState}}' "$API_SERVICE" | head -n 8 || true

sleep 2
inicio="$(fecha_utc)"
echo
log_info "Enviando 6 POST /api/ordenes con las 3 instancias recuperadas..."
for i in $(seq 1 6); do
  hacer_pedido "f4-$(printf '%02d' "$i")" || true
  sleep 0.3
done
sleep 3
capturar_logs "$inicio" "$RESULTADOS/fase4-logs.txt"
validar_fase 4 3 6 || true

# -----------------------------------------------------------------------------
# Verificación funcional: la orden se facturó por MQTT (una sola vez)
# -----------------------------------------------------------------------------
titulo "Verificación funcional del flujo MQTT (suscripción compartida)"
if [ -n "$ULTIMA_ORDEN" ]; then
  log_info "Esperando el procesamiento asíncrono de la orden #$ULTIMA_ORDEN..."
  sleep 3
  estado="$(curl -s --max-time 10 "$API_URL/api/ordenes/$ULTIMA_ORDEN" | sed -n 's/.*"estado":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  codigo_factura="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API_URL/api/facturas/orden/$ULTIMA_ORDEN" || echo 000)"
  echo "   Orden #$ULTIMA_ORDEN -> estado: ${estado:-?} | GET /api/facturas/orden/$ULTIMA_ORDEN -> HTTP $codigo_factura"
  if [ "$codigo_factura" = "200" ]; then
    log_ok "La orden fue facturada (una única vez) por alguna de las instancias del cluster."
  else
    log_warn "Todavía no hay factura para la orden #$ULTIMA_ORDEN (puede demorar unos segundos)."
  fi
  {
    echo "--- Flujo MQTT ---"
    echo "Orden #$ULTIMA_ORDEN estado='${estado:-?}' factura HTTP $codigo_factura"
    echo
  } >> "$RESUMEN"
else
  log_warn "No se registró ninguna orden exitosa; no se puede verificar el flujo MQTT."
fi

# -----------------------------------------------------------------------------
# Resumen final
# -----------------------------------------------------------------------------
titulo "RESUMEN DE LA EJECUCIÓN"
echo "   Requests enviados : $REQUEST_NUM"
echo "   HTTP 201          : $OK"
echo "   Fallidos          : $FALLIDOS"
echo "   Fases con errores : $FALLOS_ASERCION"
echo
echo "   Evidencia guardada en: $RESULTADOS"
echo "     - $CSV"
echo "     - $RESUMEN"
echo "     - fase1..fase4-logs.txt / fase*-tareas.txt"

{
  echo "=============================================================="
  echo " TOTALES"
  echo "   Requests enviados : $REQUEST_NUM"
  echo "   HTTP 201          : $OK"
  echo "   Fallidos          : $FALLIDOS"
  echo "   Fases con errores : $FALLOS_ASERCION"
  echo "   Resultado         : $([ "$FALLOS_ASERCION" -eq 0 ] && echo 'BALANCEO Y TOLERANCIA A FALLOS VALIDADOS' || echo 'REVISAR: hubo fases que no cumplieron lo esperado')"
  echo "=============================================================="
} >> "$RESUMEN"

# Muestra un extracto de logs como evidencia en pantalla
titulo "Extracto de logs de la FASE 1 (se ve la réplica que atendió cada request)"
grep '\[REQ\] POST /api/ordenes' "$RESULTADOS/fase1-logs.txt" 2>/dev/null | head -n 8 || true

if [ "$FALLOS_ASERCION" -gt 0 ]; then
  exit 1
fi

log_ok "Pruebas finalizadas correctamente."
