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

# user_mkdir USUARIO DIR... — Crea las carpetas como el usuario (así ~/.config
# y compañía nunca quedan a nombre de root).
user_mkdir() {
  local user=$1 dir
  shift
  for dir; do
    [[ -d $dir ]] || run_as_user "$user" mkdir -p -- "$dir"
  done
}

# user_install_file USUARIO ORIGEN DESTINO [MODO] — Como install_file, pero el
# archivo y sus carpetas quedan a nombre del usuario.
user_install_file() {
  local user=$1 src=$2 dst=$3 mode=${4:-644}
  user_mkdir "$user" "$(dirname -- "$dst")"
  install_file "$src" "$dst" "$mode"
  if [[ -e $dst && $(stat -c %U -- "$dst") != "$user" ]]; then
    run chown -- "$user:" "$dst"
  fi
}

# user_ensure_line USUARIO ARCHIVO LINEA — ensure_line en un archivo del usuario.
user_ensure_line() {
  local user=$1 file=$2 line=$3
  user_mkdir "$user" "$(dirname -- "$file")"
  ensure_line "$file" "$line"
  if [[ -e $file && $(stat -c %U -- "$file") != "$user" ]]; then
    run chown -- "$user:" "$file"
  fi
}

# user_write_file USUARIO DESTINO [MODO] <<'EOF' — write_file para el usuario.
user_write_file() {
  local user=$1 dst=$2 mode=${3:-644} cand
  cand=$(_candidate)
  cat >"$cand"
  user_install_file "$user" "$cand" "$dst" "$mode"
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
