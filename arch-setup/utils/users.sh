#!/usr/bin/env bash
# users.sh — Usuarios y grupos de forma idempotente.

[[ -n ${_UTILS_USERS_LOADED:-} ]] && return 0
_UTILS_USERS_LOADED=1

# user_home USUARIO — Imprime el HOME del usuario.
user_home() { getent passwd -- "$1" | cut -d: -f6; }

group_exists() { getent group -- "$1" >/dev/null 2>&1; }

# user_in_group USUARIO GRUPO
user_in_group() {
  local g
  for g in $(id -nG -- "$1" 2>/dev/null); do
    [[ $g == "$2" ]] && return 0
  done
  return 1
}

# group_ensure GRUPO [--system] — Crea el grupo si no existe.
group_ensure() {
  local group=$1
  shift
  group_exists "$group" && return 0
  run groupadd "$@" -- "$group"
  log_ok "Grupo creado: $group"
}

# user_add_group USUARIO GRUPO... — Añade a los grupos que falten (creándolos
# como grupos de sistema si no existen). Los cambios aplican al volver a iniciar sesión.
user_add_group() {
  local user=$1 group
  shift
  user_exists "$user" || die "user_add_group: no existe el usuario '$user'"
  for group; do
    group_ensure "$group" --system
    if user_in_group "$user" "$group"; then
      log_debug "$user ya está en $group"
      continue
    fi
    run usermod -aG "$group" -- "$user"
    log_ok "$user añadido a $group"
  done
}
