#!/usr/bin/env bash
# confirm.sh — Preguntas al usuario: sí/no, texto, contraseñas y menús.
#
# Con ASSUME_YES=1 (flag --yes) no se pregunta: confirm devuelve "sí" y ask/choose
# usan el valor por defecto. confirm_dangerous NUNCA se salta.

[[ -n ${_UTILS_CONFIRM_LOADED:-} ]] && return 0
_UTILS_CONFIRM_LOADED=1

_valid_var_name() {
  [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "Nombre de variable inválido: '$1'"
}

_prompt() { printf '%s?%s %s' "$_C_BOLD$_C_YELLOW" "$_C_RESET" "$1"; }

# confirm PREGUNTA [s|n] — Devuelve 0 si la respuesta es sí. Por defecto "n".
confirm() {
  local question=$1 default=${2:-n} hint reply
  [[ $default == y ]] && default=s
  if [[ $default == s ]]; then hint='[S/n]'; else hint='[s/N]'; fi

  if ((ASSUME_YES)); then
    log_debug "Auto-sí (--yes): $question"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log_warn "Sin terminal; respuesta por defecto ($default): $question"
    [[ $default == s ]] && return 0
    return 1
  fi

  while true; do
    read -r -p "$(_prompt "$question $hint ")" reply
    reply=${reply,,}
    reply=${reply:-$default}
    case $reply in
      s | si | sí | y | yes) _log_file CONFIRM "$question -> sí"; return 0 ;;
      n | no) _log_file CONFIRM "$question -> no"; return 1 ;;
      *) log_warn "Responde s o n" ;;
    esac
  done
}

# confirm_dangerous MENSAJE TEXTO — Para acciones destructivas (borrar un disco).
# Obliga a escribir TEXTO exactamente. Ignora --yes y falla sin terminal.
confirm_dangerous() {
  local message=$1 expected=$2 reply
  [[ -t 0 ]] || die "Confirmación destructiva requiere una terminal interactiva: $message"
  log_warn "$message"
  read -r -p "$(_prompt "Escribe '$expected' para continuar: ")" reply
  if [[ $reply == "$expected" ]]; then
    _log_file CONFIRM "$message -> confirmado"
    return 0
  fi
  log_warn "Cancelado."
  return 1
}

# ask PREGUNTA VARIABLE [DEFECTO] [VALIDADOR] — Lee texto y lo guarda en VARIABLE.
# Si VARIABLE ya tiene valor, se usa como defecto. VALIDADOR es el nombre de una
# función que recibe el valor y devuelve 0 si es válido.
ask() {
  local question=$1 var=$2 default=${3:-} validator=${4:-} reply
  _valid_var_name "$var"
  [[ -n ${!var:-} ]] && default=${!var}

  if ((ASSUME_YES)) || [[ ! -t 0 ]]; then
    [[ -n $default ]] || die "Falta un valor para '$var' y no se puede preguntar (--yes o sin terminal)"
    [[ -z $validator ]] || "$validator" "$default" || die "Valor inválido para $var: '$default'"
    printf -v "$var" '%s' "$default"
    log_debug "$var=$default (por defecto)"
    return 0
  fi

  while true; do
    read -r -p "$(_prompt "$question${default:+ [$default]}: ")" reply
    reply=${reply:-$default}
    if [[ -z $reply ]]; then
      log_warn "El valor no puede estar vacío"
    elif [[ -n $validator ]] && ! "$validator" "$reply"; then
      log_warn "Valor no válido: '$reply'"
    else
      break
    fi
  done
  printf -v "$var" '%s' "$reply"
  _log_file ASK "$var=$reply"
}

# ask_secret PREGUNTA VARIABLE — Contraseña oculta, pedida dos veces.
# No se registra en el log.
ask_secret() {
  local question=$1 var=$2 first second
  _valid_var_name "$var"
  [[ -t 0 ]] || die "Se necesita una terminal para pedir '$var'"
  while true; do
    read -r -s -p "$(_prompt "$question: ")" first
    printf '\n' >&2
    read -r -s -p "$(_prompt "Repite: ")" second
    printf '\n' >&2
    if [[ -z $first ]]; then
      log_warn "No puede estar vacía"
    elif [[ $first != "$second" ]]; then
      log_warn "No coinciden, inténtalo otra vez"
    else
      break
    fi
  done
  printf -v "$var" '%s' "$first"
}

# choose PREGUNTA VARIABLE OPCION... — Menú numerado. La primera opción es el
# defecto (o el valor actual de VARIABLE si es una de las opciones).
choose() {
  local question=$1 var=$2 default opt reply i
  shift 2
  (($# > 0)) || die "choose: no hay opciones"
  _valid_var_name "$var"
  default=$1
  for opt; do [[ $opt == "${!var:-}" ]] && default=$opt; done

  if ((ASSUME_YES)) || [[ ! -t 0 ]]; then
    printf -v "$var" '%s' "$default"
    log_debug "$var=$default (por defecto)"
    return 0
  fi

  printf '%s\n' "$(_prompt "$question")" >&2
  i=1
  for opt; do
    printf '   %s%2d)%s %s%s\n' "$_C_CYAN" "$i" "$_C_RESET" "$opt" \
      "$([[ $opt == "$default" ]] && printf ' %s(defecto)%s' "$_C_DIM" "$_C_RESET")" >&2
    i=$((i + 1))
  done
  while true; do
    read -r -p "   Número: " reply
    if [[ -z $reply ]]; then
      printf -v "$var" '%s' "$default"
      break
    fi
    if [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= $#)); then
      printf -v "$var" '%s' "${!reply}"
      break
    fi
    log_warn "Elige un número entre 1 y $#"
  done
  _log_file ASK "$var=${!var}"
}
