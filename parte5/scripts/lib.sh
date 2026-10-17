#!/usr/bin/env bash
# =============================================================================
#  lib.sh - Funciones y configuración compartida (Laboratorio 5 - Docker Swarm)
#  Se carga desde los scripts con:  source "$(dirname "$0")/lib.sh"
# =============================================================================

# --- Nombres de recursos -----------------------------------------------------
STACK="${STACK:-tienda_lab5}"          # nombre del stack de Docker Swarm
API_SERVICE="${STACK}_api"             # servicio de la API (3 réplicas)
DB_SERVICE="${STACK}_db"
MQTT_SERVICE="${STACK}_mosquitto"
API_IMAGE="${API_IMAGE:-ingsw2026-gafh-api:1.0.0}"
API_URL="${API_URL:-http://localhost:8080}"
# El nombre del stack se usa como prefijo de los servicios que crea Swarm.

# --- Colores (se desactivan si la salida no es una terminal) -----------------
if [ -t 1 ]; then
  C_VERDE=$'\033[0;32m'
  C_ROJO=$'\033[0;31m'
  C_AMARILLO=$'\033[1;33m'
  C_CELESTE=$'\033[0;36m'
  C_GRIS=$'\033[0;90m'
  C_NC=$'\033[0m'
else
  C_VERDE=""; C_ROJO=""; C_AMARILLO=""; C_CELESTE=""; C_GRIS=""; C_NC=""
fi

# --- Mensajes ----------------------------------------------------------------
log_info()  { printf '%s[INFO]%s %s\n'  "$C_CELESTE"  "$C_NC" "$*"; }
log_ok()    { printf '%s[ OK ]%s %s\n'  "$C_VERDE"    "$C_NC" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n'  "$C_AMARILLO" "$C_NC" "$*"; }
log_error() { printf '%s[FAIL]%s %s\n'  "$C_ROJO"     "$C_NC" "$*" >&2; }

titulo() {
  printf '\n%s======================================================================%s\n' "$C_CELESTE" "$C_NC"
  printf '%s %s%s\n' "$C_CELESTE" "$*" "$C_NC"
  printf '%s======================================================================%s\n' "$C_CELESTE" "$C_NC"
}

# --- Utilidades --------------------------------------------------------------

# Busca hacia arriba la carpeta que contiene pom.xml (raíz del proyecto Java),
# partiendo del directorio indicado. Así el zip puede descomprimirse en
# cualquier subcarpeta del repositorio.
raiz_proyecto() {
  local dir
  dir="$(cd "$1" && pwd)"
  while [ "$dir" != "/" ] && [ "$dir" != "$(dirname "$dir")" ]; do
    if [ -f "$dir/pom.xml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Verifica que el CLI de Docker exista y que el daemon responda.
verificar_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error "No se encontró el comando 'docker'. Instalá Docker Desktop / Docker Engine y volvé a intentar."
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    log_error "El daemon de Docker no responde. Iniciá Docker Desktop / el servicio docker y volvé a intentar."
    exit 1
  fi
  log_ok "Docker disponible: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?')"
}

# Devuelve 'active' si el nodo ya es parte de un swarm, 'inactive' si no.
estado_swarm() {
  docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "desconocido"
}

# Cantidad de tareas efectivamente corriendo para un servicio.
replicas_corriendo() {
  local servicio="$1" cantidad
  cantidad=$(docker service ps --filter desired-state=running \
      --format '{{.CurrentState}}' "$servicio" 2>/dev/null | grep -c '^Running' || true)
  printf '%s\n' "${cantidad:-0}"
}

# Espera a que un servicio tenga exactamente N réplicas corriendo.
# Uso: esperar_replicas <servicio> <cantidad> [timeout_segundos]
esperar_replicas() {
  local servicio="$1" deseadas="$2" timeout="${3:-300}" inicio corriendo transcurrido
  inicio=$(date +%s)
  while :; do
    corriendo="$(replicas_corriendo "$servicio")"
    if [ "$corriendo" = "$deseadas" ]; then
      log_ok "Servicio '$servicio' convergió: $corriendo/$deseadas réplicas corriendo."
      return 0
    fi
    transcurrido=$(( $(date +%s) - inicio ))
    if [ "$transcurrido" -ge "$timeout" ]; then
      log_error "Timeout esperando '$servicio' ($corriendo/$deseadas después de ${transcurrido}s)."
      return 1
    fi
    printf '%s       ... %s: %s/%s réplicas (%ss)%s\n' \
      "$C_GRIS" "$servicio" "$corriendo" "$deseadas" "$transcurrido" "$C_NC"
    sleep 5
  done
}

# Muestra el estado resumido del stack (servicios + tareas).
mostrar_estado() {
  titulo "Estado del stack '$STACK'"
  docker stack services "$STACK" 2>/dev/null || log_warn "Todavía no existe el stack '$STACK'."
  echo
  log_info "Tareas del servicio '$API_SERVICE' (una por nodo/réplica):"
  docker service ps --format '  {{.Name}}  {{.CurrentState}}  nodo={{.Node}}  error={{.Error}}' \
      "$API_SERVICE" 2>/dev/null || true
}

# Cuenta cuántos requests POST /api/ordenes atendió cada instancia, a partir de
# un archivo de logs capturado con `docker service logs`.
# Salida: "<cantidad> <instancia>" por línea, ordenado por instancia.
contar_por_instancia() {
  local archivo="$1"
  grep '\[REQ\] POST /api/ordenes' "$archivo" 2>/dev/null \
    | grep -o 'instancia=[^ ]*' \
    | sed 's/^instancia=//' \
    | sort | uniq -c | sort -k2 || true
}

# Cantidad total de líneas [REQ] POST /api/ordenes en un archivo de logs.
contar_requests() {
  local archivo="$1"
  grep -c '\[REQ\] POST /api/ordenes' "$archivo" 2>/dev/null || true
}
