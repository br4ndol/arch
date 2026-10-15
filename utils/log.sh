#!/usr/bin/env bash
# log.sh — Mensajes por pantalla (stderr) y registro en archivo.
#
# Todo va a stderr para que las funciones que "devuelven" por stdout no se
# mezclen con los mensajes.

[[ -n ${_UTILS_LOG_LOADED:-} ]] && return 0
_UTILS_LOG_LOADED=1

: "${LOG_FILE:=}"

if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
  _C_RESET=$'\e[0m' _C_BOLD=$'\e[1m' _C_DIM=$'\e[2m'
  _C_RED=$'\e[31m' _C_GREEN=$'\e[32m' _C_YELLOW=$'\e[33m'
  _C_BLUE=$'\e[34m' _C_MAGENTA=$'\e[35m' _C_CYAN=$'\e[36m'
else
  _C_RESET='' _C_BOLD='' _C_DIM='' _C_RED='' _C_GREEN='' _C_YELLOW=''
  _C_BLUE='' _C_MAGENTA='' _C_CYAN=''
fi

# log_init [ARCHIVO] — Activa el registro en archivo. Sin argumento usa
# /var/log/arch-setup.log, o /tmp si /var/log no es escribible.
log_init() {
  local file=${1:-}
  if [[ -z $file ]]; then
    if [[ -w /var/log ]]; then file=/var/log/arch-setup.log; else file="${TMPDIR:-/tmp}/arch-setup.log"; fi
  fi
  if ! mkdir -p -- "$(dirname -- "$file")" 2>/dev/null || ! touch -- "$file" 2>/dev/null; then
    file="${TMPDIR:-/tmp}/arch-setup.log"
    touch -- "$file"
  fi
  LOG_FILE=$file
  export LOG_FILE
  printf '\n===== %s  %s =====\n' "$(date '+%F %T')" "${0##*/}" >>"$LOG_FILE"
}

# _log NIVEL COLOR MARCA MENSAJE...
_log() {
  local level=$1 color=$2 mark=$3
  shift 3
  printf '%s%s%s %s\n' "$color" "$mark" "$_C_RESET" "$*" >&2
  _log_file "$level" "$*"
}

# _log_file NIVEL MENSAJE — Solo al archivo (si está activo).
_log_file() {
  [[ -n $LOG_FILE ]] || return 0
  printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >>"$LOG_FILE" 2>/dev/null || true
}

log_info()  { _log INFO  "$_C_BLUE"   '  ->' "$@"; }
log_ok()    { _log OK    "$_C_GREEN"  '  ✓' "$@"; }
log_warn()  { _log WARN  "$_C_YELLOW" '  !' "$@"; }
log_error() { _log ERROR "$_C_RED"    '  ✗' "$@"; }
log_dry()   { _log DRY   "$_C_MAGENTA" '  [dry-run]' "$@"; }

# log_debug — Solo se muestra con VERBOSE=1, pero siempre queda en el archivo.
log_debug() {
  if ((VERBOSE)); then
    _log DEBUG "$_C_DIM" '  ·' "$@"
  else
    _log_file DEBUG "$*"
  fi
}

# log_step MENSAJE — Paso dentro de un módulo.
log_step() { _log STEP "$_C_BOLD$_C_CYAN" '::' "$_C_BOLD$*$_C_RESET"; }

# log_section TITULO — Encabezado grande (inicio de módulo o fase).
log_section() {
  local line
  printf -v line '%*s' 60 ''
  line=${line// /═}
  printf '\n%s%s%s\n%s  %s%s\n%s%s%s\n' \
    "$_C_BOLD$_C_BLUE" "$line" "$_C_RESET" \
    "$_C_BOLD" "$*" "$_C_RESET" \
    "$_C_BOLD$_C_BLUE" "$line" "$_C_RESET" >&2
  _log_file SECTION "$*"
}

# die MENSAJE — Error fatal: registra y sale con código 1.
die() {
  log_error "$@"
  exit 1
}
