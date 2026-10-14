#!/usr/bin/env bash
# common.sh — Punto de entrada de utils: modo estricto, traps y carga de helpers.
#
# Uso (desde un orquestador o módulo):
#   source "$ROOT_DIR/utils/common.sh"

[[ -n ${_UTILS_COMMON_LOADED:-} ]] && return 0
_UTILS_COMMON_LOADED=1

set -Eeuo pipefail
shopt -s inherit_errexit

UTILS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname -- "$UTILS_DIR")"
CONFIG_DIR="$ROOT_DIR/config"
MODULES_DIR="$ROOT_DIR/modules"

# Opciones globales (se exportan para que los módulos, que corren en un
# proceso hijo, las hereden).
: "${DRY_RUN:=0}" "${ASSUME_YES:=0}" "${VERBOSE:=0}"
# Marca de tiempo de la ejecución: compartida por todos los módulos para que
# los backups de un mismo archivo no se pisen entre sí.
: "${RUN_TS:=$(date +%F-%H%M%S)}"
export ROOT_DIR CONFIG_DIR MODULES_DIR DRY_RUN ASSUME_YES VERBOSE RUN_TS

# Directorio temporal propio de este proceso; se borra al salir.
RUN_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/arch-setup.XXXXXX")"

for _f in log confirm execute checks files packages services users; do
  # shellcheck source=/dev/null
  source "$UTILS_DIR/$_f.sh"
done
unset _f

_on_error() {
  local rc=$? cmd=$BASH_COMMAND i
  log_error "Falló (código $rc): $cmd"
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    log_error "  en ${FUNCNAME[i]}() ${BASH_SOURCE[i]}:${BASH_LINENO[i - 1]}"
  done
}

_on_exit() {
  local fn
  if [[ -n ${RUN_TMPDIR:-} && -d $RUN_TMPDIR ]]; then rm -rf -- "$RUN_TMPDIR"; fi
  for fn in "${_CLEANUP_FNS[@]}"; do "$fn" || true; done
}

_CLEANUP_FNS=()
# add_cleanup FUNCION — registra una función que se ejecuta al salir (en orden
# inverso al registro).
add_cleanup() { _CLEANUP_FNS=("$1" "${_CLEANUP_FNS[@]}"); }

trap _on_error ERR
trap _on_exit EXIT

# load_config — Carga config/settings.conf y, si existe, config/settings.local.conf
# (este último no se versiona: discos, usuario, etc. de cada máquina).
# Todas las variables quedan exportadas.
load_config() {
  local base="$CONFIG_DIR/settings.conf" local_conf="$CONFIG_DIR/settings.local.conf"
  [[ -f $base ]] || die "No existe $base"
  set -a
  # shellcheck source=/dev/null
  source "$base"
  if [[ -f $local_conf ]]; then
    # shellcheck source=/dev/null
    source "$local_conf"
    log_debug "Configuración cargada: $base + $local_conf"
  else
    log_debug "Configuración cargada: $base"
  fi
  set +a
}
