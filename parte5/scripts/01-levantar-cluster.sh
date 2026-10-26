#!/usr/bin/env bash
# =============================================================================
#  01-levantar-cluster.sh
#  Laboratorio 5 - Docker Swarm
#
#  Este script:
#    1. Verifica que Docker esté corriendo.
#    2. Inicializa Docker Swarm (si el nodo todavía no es parte de un swarm).
#    3. Construye la imagen de la API (la misma imagen para las 3 réplicas).
#    4. Despliega el stack con `docker stack deploy` (3 réplicas de la API).
#    5. Espera a que las 3 réplicas estén corriendo y hace un smoke test.
#
#  Uso:
#      ./01-levantar-cluster.sh
#    o (desde Windows, Git Bash):
#      bash scripts/01-levantar-cluster.sh
#
#  Variables opcionales:
#      STACK=tienda_lab5                     nombre del stack
#      API_IMAGE=ingsw2026-gafh-api:1.0.0    nombre/tag de la imagen
#      ADVERTISE_ADDR=192.168.0.10           IP a anunciar si `swarm init` falla
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

PROYECTO="$(raiz_proyecto "$SCRIPT_DIR")" || {
  log_error "No se encontró 'pom.xml'. El zip debe estar dentro del proyecto Java (IngSw2026-GAFH)."
  exit 1
}

titulo "PASO 1/5 - Verificando Docker"
verificar_docker

titulo "PASO 2/5 - Inicializando Docker Swarm (si hace falta)"
if [ "$(estado_swarm)" = "active" ]; then
  log_ok "El nodo ya es parte de un swarm."
else
  log_info "El nodo no está en modo swarm. Ejecutando 'docker swarm init'..."
  if [ -n "${ADVERTISE_ADDR:-}" ]; then
    docker swarm init --advertise-addr "$ADVERTISE_ADDR"
  elif ! docker swarm init; then
    log_error "No se pudo inicializar el swarm (¿la máquina tiene varias interfaces de red?)."
    log_error "Reintentá indicando la IP:  ADVERTISE_ADDR=<IP-LAN> ./01-levantar-cluster.sh"
    exit 1
  fi
  log_ok "Swarm inicializado. Este nodo es el manager."
fi
docker node ls

titulo "PASO 3/5 - Construyendo la imagen de la API"
log_info "Contexto de build: $PROYECTO"
log_info "Imagen: $API_IMAGE (la usan las 3 réplicas, es la misma imagen)"
docker build -t "$API_IMAGE" "$PROYECTO"
log_ok "Imagen construida: $API_IMAGE"

# Aviso: si otro contenedor ya publica el 8080, la API no será accesible en ese puerto.
if docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -q '0\.0\.0\.0:8080'; then
  log_warn "Hay un contenedor ocupando el puerto 8080:"
  docker ps --format '  {{.Names}} -> {{.Ports}}' 2>/dev/null | grep '0\.0\.0\.0:8080' || true
  log_warn "Bajalo antes de probar la API (en la raíz del proyecto: docker compose down)."
fi

titulo "PASO 4/5 - Desplegando el stack '$STACK' (3 réplicas)"
cd "$SCRIPT_DIR/.."

# `docker stack deploy` a veces falla si se acaba de bajar el stack anterior:
# Swarm todavía está eliminando la red overlay y el CLI la encuentra a medias.
# Por eso se reintenta el despliegue unas cuantas veces.
desplegar_stack() {
  local intento=1
  while :; do
    if API_IMAGE="$API_IMAGE" docker stack deploy -c docker-compose.yml "$STACK"; then
      return 0
    fi
    if [ "$intento" -ge 3 ]; then
      log_error "No se pudo desplegar el stack después de $intento intentos."
      return 1
    fi
    intento=$((intento + 1))
    log_warn "El despliegue falló (Swarm puede estar liberando la red del stack anterior)."
    log_warn "Reintentando en 10 segundos (intento $intento/3)..."
    sleep 10
  done
}

desplegar_stack

titulo "PASO 5/5 - Esperando que las 3 réplicas estén listas"

# El compose usa `restart_policy: none` para la API: si una tarea arranca antes de
# que MySQL esté listo, falla y NO se re-crea sola. Por eso primero se espera a que
# MySQL esté saludable y, si hace falta, se fuerza un nuevo intento de la API.
esperar_db_saludable() {
  local timeout="${1:-300}" inicio estado
  inicio=$(date +%s)
  log_info "Esperando a que MySQL esté saludable (puede tardar en el primer arranque)..."
  while :; do
    estado=$(docker ps --filter "label=com.docker.swarm.service.name=$DB_SERVICE" \
      --format '{{.Status}}' 2>/dev/null | grep -c 'healthy' || true)
    if [ "${estado:-0}" -ge 1 ]; then
      log_ok "MySQL está saludable."
      return 0
    fi
    if [ $(( $(date +%s) - inicio )) -ge "$timeout" ]; then
      log_warn "MySQL no reportó 'healthy' en ${timeout}s; se continúa igual."
      return 1
    fi
    sleep 5
  done
}

esperar_db_saludable 300 || true

corriendo="$(replicas_corriendo "$API_SERVICE")"
if [ "$corriendo" -lt 3 ]; then
  log_warn "La API tiene $corriendo/3 réplicas (con restart_policy=none no se reponen solas)."
  log_info "Recreando las tareas de la API con MySQL ya listo..."
  docker service update --force "$API_SERVICE" >/dev/null
fi

esperar_replicas "$API_SERVICE" 3 300 || true
if ! esperar_servicio_estable 3 420; then
  log_warn "El servicio no quedó estable; se fuerza un nuevo intento..."
  docker service update --force "$API_SERVICE" >/dev/null
  esperar_servicio_estable 3 300 || log_warn "Revisá 'docker service ps $API_SERVICE' y los logs."
fi
mostrar_estado

# --- Smoke test -------------------------------------------------------------
log_info "Smoke test: GET $API_URL/api/productos"
codigo="000"
for intento in 1 2 3 4 5 6 7 8 9 10; do
  codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$API_URL/api/productos" || echo "000")
  [ "$codigo" = "200" ] && break
  sleep 3
done
if [ "$codigo" = "200" ]; then
  log_ok "La API responde en $API_URL (HTTP 200)."
else
  log_warn "La API todavía no responde correctamente (HTTP $codigo)."
  log_warn "Si ves 'Server: nginx' o un 404, revisá si otro contenedor está usando el 8080."
  log_warn "Revisá los logs con:  docker service logs -f --tail 100 $API_SERVICE"
fi

echo
log_ok "Cluster levantado. Próximo paso:"
printf '        %sbash scripts/02-pruebas-balanceo.sh%s\n\n' "$C_VERDE" "$C_NC"
printf '  Panel de Swarm : %sdocker stack services %s%s\n' "$C_GRIS" "$STACK" "$C_NC"
printf '  Logs en vivo   : %sdocker service logs -f %s%s\n' "$C_GRIS" "$API_SERVICE" "$C_NC"
printf '  Bajar todo     : %sbash scripts/03-bajar-cluster.sh%s\n\n' "$C_GRIS" "$C_NC"
