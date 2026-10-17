#!/usr/bin/env bash
# =============================================================================
#  03-bajar-cluster.sh
#  Baja el stack del Laboratorio 5 y (opcionalmente) limpia datos y el swarm.
#
#  Uso:
#      bash scripts/03-bajar-cluster.sh                 # baja el stack
#      bash scripts/03-bajar-cluster.sh --borrar-datos  # además borra el volumen MySQL
#      bash scripts/03-bajar-cluster.sh --salir-swarm   # además saca el nodo del swarm
#      bash scripts/03-bajar-cluster.sh --todo          # las dos opciones anteriores
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

BORRAR_DATOS=0
SALIR_SWARM=0

for arg in "$@"; do
  case "$arg" in
    --borrar-datos) BORRAR_DATOS=1 ;;
    --salir-swarm)  SALIR_SWARM=1 ;;
    --todo)         BORRAR_DATOS=1; SALIR_SWARM=1 ;;
    -h|--help)
      cat <<'AYUDA'
Uso:
  bash scripts/03-bajar-cluster.sh [opciones]

Opciones:
  --borrar-datos   además borra el volumen de MySQL (la próxima vez se re-inicializa)
  --salir-swarm    además saca este nodo del swarm (docker swarm leave --force)
  --todo           equivale a --borrar-datos + --salir-swarm
  -h, --help       muestra esta ayuda
AYUDA
      exit 0
      ;;
    *)
      log_error "Opción desconocida: $arg"
      exit 1
      ;;
  esac
done

titulo "Bajando el stack '$STACK'"
verificar_docker

if [ -z "$(docker stack services "$STACK" 2>/dev/null)" ]; then
  log_warn "El stack '$STACK' no existe o ya fue bajado."
else
  docker stack rm "$STACK"
  log_info "Esperando a que Swarm elimine los servicios, los contenedores y la red..."
  for intento in $(seq 1 60); do
    # Hay que esperar también a que desaparezca la red overlay: si se vuelve a
    # desplegar el stack antes de que termine, el deploy falla con
    # "network tienda_lab5_default not found".
    if [ -z "$(docker stack services "$STACK" 2>/dev/null)" ] \
       && ! docker network inspect "${STACK}_default" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  log_ok "Stack '$STACK' eliminado."
fi

if [ "$BORRAR_DATOS" -eq 1 ]; then
  log_info "Borrando el volumen de MySQL (la próxima vez se re-inicializa el schema)..."
  for volumen in "${STACK}_mysql_data" "tienda_lab5_mysql_data"; do
    if docker volume inspect "$volumen" >/dev/null 2>&1; then
      if docker volume rm "$volumen" >/dev/null 2>&1; then
        log_ok "Volumen '$volumen' borrado."
      else
        log_warn "No se pudo borrar el volumen '$volumen' (¿algún contenedor lo está usando?)."
      fi
    fi
  done
fi

if [ "$SALIR_SWARM" -eq 1 ]; then
  if [ "$(estado_swarm)" = "active" ]; then
    log_info "Sacando este nodo del swarm (docker swarm leave --force)..."
    docker swarm leave --force || log_warn "No se pudo salir del swarm."
    log_ok "Nodo fuera del swarm."
  else
    log_warn "El nodo no está en un swarm."
  fi
fi

echo
log_ok "Listo. Para volver a levantar el cluster: bash scripts/01-levantar-cluster.sh"
