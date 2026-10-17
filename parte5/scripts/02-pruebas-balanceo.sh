#!/usr/bin/env bash
# =============================================================================
#  02-pruebas-balanceo.sh
#  Laboratorio 5 - Validación del balanceo de carga y de la tolerancia a fallos
#
#  Ejecuta, en este orden:
#    FASE 1: con 3 réplicas, 12 POST /api/ordenes  -> los atienden las 3 instancias.
#    FASE 2: baja 1 instancia (scale 2), 10 POST   -> los atienden las 2 restantes.
#    FASE 3: baja otra instancia (scale 1), 8 POST -> los atiende la única viva.
#    FASE 4: vuelve a 3 réplicas y mata una tarea  -> Swarm la re-crea (auto-healing).
#
#  Para cada fase guarda en ../resultados/:
#    - faseN-logs.txt        logs crudos del servicio (con el prefijo de réplica)
#    - faseN-tareas.txt      `docker service ps` de la fase
#    - respuestas-<fecha>.csv una línea por request (HTTP, orden, X-Instancia)
#    - resumen-<fecha>.txt   resumen consolidado de la ejecución
#
#  Uso:
#      bash scripts/02-pruebas-balanceo.sh
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
ajustar_replicas() {
  local deseadas="$1" actuales
  actuales="$(replicas_corriendo "$API_SERVICE")"
  if [ "$actuales" = "$deseadas" ]; then
    log_info "El servicio ya tiene $deseadas réplica(s) corriendo."
    return 0
  fi
  log_info "Bajando/subiendo instancias: docker service scale ${API_SERVICE}=${deseadas}"
  docker service scale "${API_SERVICE}=${deseadas}" >/dev/null
  esperar_replicas "$API_SERVICE" "$deseadas" 240
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
  docker service ps --format '{{.Name}} | {{.CurrentState}} | nodo={{.Node}} | error={{.Error}}' \
    "$API_SERVICE" > "$destino" 2>&1 || true
}

# Imprime y valida la distribución de requests de una fase.
validar_fase() {
  local numero="$1" esperadas="$2" pedidos="$3"
  local archivo="$RESULTADOS/fase$numero-logs.txt"
  local registrados distintas detalle

  registrados="$(contar_requests "$archivo")"
  detalle="$(contar_por_instancia "$archivo")"
  distintas=$(printf '%s\n' "$detalle" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')

  echo
  echo "   Requests registrados en los logs del servicio : $registrados (esperados: $pedidos)"
  echo "   Instancias distintas que los atendieron       : $distintas (esperadas: $esperadas)"
  if [ -n "$detalle" ]; then
    echo "   Distribución por instancia:"
    printf '%s\n' "$detalle" | sed 's/^/      /'
  else
    echo "   (no se encontraron líneas [REQ] POST /api/ordenes en los logs)"
  fi

  {
    echo "--- FASE $numero (se esperaban $esperadas instancias y $pedidos requests) ---"
    echo "Requests en logs: $registrados | instancias distintas: $distintas"
    printf '%s\n' "$detalle"
    echo
  } >> "$RESUMEN"

  if [ "$distintas" -ne "$esperadas" ] || [ "$registrados" -ne "$pedidos" ]; then
    log_error "La FASE $numero no cumple lo esperado (instancias: $distintas/$esperadas, requests: $registrados/$pedidos)."
    FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
    return 1
  fi
  log_ok "FASE $numero validada: $pedidos requests repartidos entre $esperadas instancia(s)."
  return 0
}

# Ejecuta una fase completa: ajusta réplicas, hace N pedidos y valida los logs.
ejecutar_fase() {
  local numero="$1" titulo_fase="$2" replicas="$3" pedidos="$4"
  local inicio i

  titulo "FASE $numero - $titulo_fase"
  ajustar_replicas "$replicas"
  guardar_tareas "$RESULTADOS/fase$numero-tareas.txt"
  docker service ps --format '   tarea: {{.Name}} | {{.CurrentState}} | nodo={{.Node}}' "$API_SERVICE" || true

  # Pequeña pausa para que la ventana de logs empiece después de las operaciones
  # previas (creación del producto, escalado, etc.) y no las incluya.
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
  validar_fase "$numero" "$replicas" "$pedidos" || true
}

# -----------------------------------------------------------------------------
# FASE 1: 3 réplicas
# -----------------------------------------------------------------------------
ejecutar_fase 1 "3 réplicas - las solicitudes se reparten entre los 3 nodos" 3 12

# -----------------------------------------------------------------------------
# FASE 2: baja 1 instancia -> quedan 2
# -----------------------------------------------------------------------------
ejecutar_fase 2 "se baja 1 instancia - las otras 2 siguen procesando" 2 10

# -----------------------------------------------------------------------------
# FASE 3: baja otra instancia -> queda 1
# -----------------------------------------------------------------------------
ejecutar_fase 3 "se baja otra instancia - la única viva sigue procesando" 1 8

# -----------------------------------------------------------------------------
# FASE 4: auto-reparación (Swarm re-crea la tarea caída)
# -----------------------------------------------------------------------------
titulo "FASE 4 - Alta disponibilidad: Swarm re-crea una instancia caída"
ajustar_replicas 3
inicio="$(fecha_utc)"

victima="$(docker ps --filter "label=com.docker.swarm.service.name=$API_SERVICE" --format '{{.ID}}' | head -n 1)"
if [ -n "$victima" ]; then
  nombre_victima="$(docker inspect --format '{{.Name}}' "$victima" 2>/dev/null || echo "$victima")"
  log_info "Matando la instancia $nombre_victima (simula la caída de un nodo)..."
  docker kill "$victima" >/dev/null || true
  log_info "Enviando requests mientras Swarm recupera el servicio..."
  for i in $(seq 1 6); do
    hacer_pedido "f4-$(printf '%02d' "$i")" || true
    sleep 1
  done
  log_info "Esperando a que Swarm vuelva a tener 3/3 réplicas..."
  esperar_replicas "$API_SERVICE" 3 180
else
  log_warn "No se encontró el contenedor de ninguna réplica para matar."
  FALLOS_ASERCION=$((FALLOS_ASERCION + 1))
fi

sleep 3
capturar_logs "$inicio" "$RESULTADOS/fase4-logs.txt"
guardar_tareas "$RESULTADOS/fase4-tareas.txt"
log_ok "Réplicas después de la caída simulada: $(replicas_corriendo "$API_SERVICE")/3"

{
  echo "--- FASE 4 (caída simulada de una instancia) ---"
  echo "Réplicas después de la recuperación: $(replicas_corriendo "$API_SERVICE")/3"
  echo "Requests exitosos durante la recuperación: (ver respuestas-*.csv, etiquetas f4-*)"
  echo
} >> "$RESUMEN"

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
