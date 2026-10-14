#!/usr/bin/env bash
# execute.sh — Ejecutar comandos: registro, modo dry-run, reintentos y otro usuario.
#
# Regla: todo comando que CAMBIE el sistema pasa por `run` (o por una función
# que lo use), así --dry-run lo intercepta. Las comprobaciones de solo lectura
# se ejecutan directamente.

[[ -n ${_UTILS_EXECUTE_LOADED:-} ]] && return 0
_UTILS_EXECUTE_LOADED=1

# quote_cmd CMD... — Imprime el comando escapado, listo para copiar y pegar.
quote_cmd() {
  local out
  printf -v out '%q ' "$@"
  printf '%s' "${out% }"
}

# run CMD... — Ejecuta y registra. Con DRY_RUN=1 solo lo muestra.
run() {
  local cmd
  cmd=$(quote_cmd "$@")
  if ((DRY_RUN)); then
    log_dry "$cmd"
    return 0
  fi
  log_debug "\$ $cmd"
  "$@"
}

# run_quiet CMD... — Como run, pero la salida va solo al log. Si falla, muestra
# las últimas líneas para poder diagnosticar.
run_quiet() {
  local cmd out rc=0
  cmd=$(quote_cmd "$@")
  if ((DRY_RUN)); then
    log_dry "$cmd"
    return 0
  fi
  log_debug "\$ $cmd"
  out="$RUN_TMPDIR/run_quiet.out"
  "$@" >"$out" 2>&1 || rc=$?
  [[ -n $LOG_FILE ]] && cat -- "$out" >>"$LOG_FILE"
  if ((rc != 0)); then
    log_error "Falló ($rc): $cmd"
    tail -n 20 -- "$out" | sed 's/^/      /' >&2
  fi
  return "$rc"
}

# retry INTENTOS ESPERA CMD... — Reintenta CMD (vía run) hasta INTENTOS veces.
# Útil para red, pacman (bloqueo de la base de datos) y flatpak.
retry() {
  local attempts=$1 delay=$2 n=1
  shift 2
  until run "$@"; do
    if ((n >= attempts)); then
      log_error "Falló tras $attempts intentos: $(quote_cmd "$@")"
      return 1
    fi
    log_warn "Intento $n/$attempts falló; reintento en ${delay}s"
    sleep "$delay"
    n=$((n + 1))
  done
}

# run_as_user USUARIO CMD... — Ejecuta como otro usuario con su HOME y entorno
# básico. Necesario para paru/yay (no corren como root) y gsettings.
run_as_user() {
  local user=$1 home
  shift
  if [[ $(id -un) == "$user" ]]; then
    run "$@"
    return
  fi
  is_root || die "run_as_user: hace falta root para ejecutar como '$user'"
  user_exists "$user" || die "run_as_user: no existe el usuario '$user'"
  home=$(user_home "$user")
  run runuser -u "$user" -- env HOME="$home" USER="$user" LOGNAME="$user" \
    XDG_RUNTIME_DIR="/run/user/$(id -u "$user")" "$@"
}

# chroot_run RAIZ CMD... — Ejecuta un comando dentro de RAIZ con arch-chroot.
chroot_run() {
  local root=$1
  shift
  run arch-chroot "$root" "$@"
}
