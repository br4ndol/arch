#!/usr/bin/env bash
# services.sh — Habilitar/deshabilitar servicios de systemd de forma idempotente.
#
# En chroot (instalación) solo se habilitan: no hay systemd corriendo para
# arrancarlos. En el sistema instalado, --now además los arranca.

[[ -n ${_UTILS_SERVICES_LOADED:-} ]] && return 0
_UTILS_SERVICES_LOADED=1

# service_enable [--now] UNIDAD...
service_enable() {
  local now=0 unit
  if [[ ${1:-} == --now ]]; then
    now=1
    shift
  fi
  if ((now)) && ! systemd_running; then
    log_debug "systemd no está activo (chroot); se habilita sin --now"
    now=0
  fi
  for unit; do
    if systemctl is-enabled --quiet -- "$unit" 2>/dev/null; then
      log_debug "Ya habilitado: $unit"
    else
      run systemctl enable -- "$unit"
      log_ok "Habilitado: $unit"
    fi
    if ((now)) && ! systemctl is-active --quiet -- "$unit"; then
      run systemctl start -- "$unit"
      log_ok "Iniciado: $unit"
    fi
  done
}

# service_disable [--now] UNIDAD...
service_disable() {
  local now=0 unit
  if [[ ${1:-} == --now ]]; then
    now=1
    shift
  fi
  systemd_running || now=0
  for unit; do
    if systemctl is-enabled --quiet -- "$unit" 2>/dev/null; then
      run systemctl disable -- "$unit"
      log_ok "Deshabilitado: $unit"
    fi
    if ((now)) && systemctl is-active --quiet -- "$unit"; then
      run systemctl stop -- "$unit"
    fi
  done
}

# service_enable_global UNIDAD... — Servicio de usuario habilitado para TODOS
# los usuarios (systemctl --global). Funciona sin sesión, también en chroot.
service_enable_global() {
  local unit
  for unit; do
    if systemctl --global is-enabled --quiet -- "$unit" 2>/dev/null; then
      log_debug "Ya habilitado (global): $unit"
      continue
    fi
    run systemctl --global enable -- "$unit"
    log_ok "Habilitado (global): $unit"
  done
}

# service_enable_user USUARIO UNIDAD... — Servicio de usuario para un usuario
# concreto. Requiere que su gestor de systemd esté activo (sesión iniciada).
service_enable_user() {
  local user=$1 unit
  shift
  for unit; do
    if systemctl --user -M "$user@" is-enabled --quiet -- "$unit" 2>/dev/null; then
      log_debug "Ya habilitado ($user): $unit"
      continue
    fi
    run systemctl --user -M "$user@" enable --now -- "$unit"
    log_ok "Habilitado ($user): $unit"
  done
}
