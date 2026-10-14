#!/usr/bin/env bash
# modules.sh — Flags comunes de los orquestadores y ejecución de módulos.
#
# Convención de un módulo (modules/<fase>/<nombre>.sh):
#
#   #!/usr/bin/env bash
#   # desc: Descripción corta que aparece en --list
#   module_run() {
#     log_step "Haciendo algo"
#     pkg_install foo
#   }
#
# Cada módulo se ejecuta en un proceso bash hijo que vuelve a cargar
# utils/common.sh y la configuración: así `set -e` funciona de verdad dentro
# del módulo, un fallo no deja variables sueltas en el orquestador, y lo que
# un módulo guarde en settings.local.conf lo ven los siguientes.

[[ -n ${_UTILS_MODULES_LOADED:-} ]] && return 0
_UTILS_MODULES_LOADED=1

ONLY_MODULES=()
SKIP_MODULES=()
LIST_ONLY=0
KEEP_GOING=0
EXTRA_ARGS=()

# common_usage — Ayuda de los flags comunes (los orquestadores la incluyen).
common_usage() {
  cat <<'EOF'
Opciones comunes:
  -n, --dry-run         Muestra lo que haría, sin cambiar nada
  -y, --yes             No pregunta: acepta todo (salvo borrar discos)
  -v, --verbose         Muestra mensajes de depuración
  -l, --list            Lista los módulos y sale
  -o, --only A,B        Ejecuta solo esos módulos
  -s, --skip A,B        Salta esos módulos
  -k, --keep-going      Si un módulo falla, sigue con el siguiente
  -h, --help            Esta ayuda
EOF
}

# parse_common_args ARGS... — Procesa los flags comunes; lo que no reconoce
# queda en EXTRA_ARGS para el orquestador. Llama a `usage` con -h.
parse_common_args() {
  local -a list
  while (($#)); do
    # shellcheck disable=SC2034  # LIST_ONLY lo leen los orquestadores
    case $1 in
      -n | --dry-run) DRY_RUN=1 ;;
      -y | --yes) ASSUME_YES=1 ;;
      -v | --verbose) VERBOSE=1 ;;
      -l | --list) LIST_ONLY=1 ;;
      -k | --keep-going) KEEP_GOING=1 ;;
      -o | --only | -s | --skip)
        [[ -n ${2:-} ]] || die "$1 necesita una lista de módulos (a,b,c)"
        IFS=, read -ra list <<<"$2"
        if [[ $1 == -o || $1 == --only ]]; then ONLY_MODULES+=("${list[@]}"); else SKIP_MODULES+=("${list[@]}"); fi
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) EXTRA_ARGS+=("$1") ;;
    esac
    shift
  done
  export DRY_RUN ASSUME_YES VERBOSE
}

_in_list() {
  local needle=$1 item
  shift
  for item; do [[ $item == "$needle" ]] && return 0; done
  return 1
}

_module_selected() {
  local name=$1
  if ((${#ONLY_MODULES[@]})) && ! _in_list "$name" "${ONLY_MODULES[@]}"; then return 1; fi
  if ((${#SKIP_MODULES[@]})) && _in_list "$name" "${SKIP_MODULES[@]}"; then return 1; fi
  return 0
}

# module_desc ARCHIVO — Imprime la línea "# desc:" del módulo.
module_desc() { awk '/^# desc:/ { sub(/^# desc:[ \t]*/, ""); print; exit }' "$1"; }

# list_modules TITULO DIR NOMBRE... — Para --list.
list_modules() {
  local title=$1 dir=$2 name file desc
  shift 2
  printf '%s%s%s\n' "$_C_BOLD" "$title" "$_C_RESET"
  if (($# == 0)); then
    printf '   (sin módulos)\n'
    return 0
  fi
  for name; do
    file="$dir/$name.sh"
    if [[ -f $file ]]; then desc=$(module_desc "$file"); else desc="(no existe $file)"; fi
    printf '   %s%-14s%s %s\n' "$_C_CYAN" "$name" "$_C_RESET" "$desc"
  done
}

# run_modules DIR NOMBRE... — Ejecuta en orden los módulos seleccionados.
# Se detiene en el primer fallo (salvo --keep-going) y muestra un resumen.
run_modules() {
  local dir=$1 name file rc
  local -a ok=() failed=() skipped=()
  shift
  for name; do
    [[ -f "$dir/$name.sh" ]] || die "No existe el módulo: $dir/$name.sh"
  done

  for name; do
    file="$dir/$name.sh"
    if ! _module_selected "$name"; then
      skipped+=("$name")
      continue
    fi
    log_section "Módulo: $name — $(module_desc "$file")"
    rc=0
    # shellcheck disable=SC2016  # $1/$2 se expanden en el bash hijo
    "$BASH" -c '
      source "$1"
      load_config
      source "$2"
      declare -F module_run >/dev/null || die "El módulo $2 no define module_run()"
      module_run
    ' "arch-setup:$name" "$UTILS_DIR/common.sh" "$file" || rc=$?
    if ((rc == 0)); then
      ok+=("$name")
      log_ok "Módulo $name terminado"
      continue
    fi
    failed+=("$name")
    log_error "Módulo $name falló (código $rc)"
    ((KEEP_GOING)) || break
  done

  log_section "Resumen"
  ((${#ok[@]} == 0)) || log_ok "Correctos: ${ok[*]}"
  ((${#skipped[@]} == 0)) || log_info "Saltados: ${skipped[*]}"
  if ((${#failed[@]})); then
    log_error "Fallidos: ${failed[*]}"
    log_info "Corrige y repite solo esos con: --only $(IFS=,; printf '%s' "${failed[*]}")"
    [[ -n $LOG_FILE ]] && log_info "Log: $LOG_FILE"
    return 1
  fi
  return 0
}
