#!/usr/bin/env bash
# desc: Usuario (grupo wheel con sudo) y la misma contraseña para él y root

module_run() {
  [[ -n $PASSWORD_HASH ]] || die "Falta PASSWORD_HASH (módulo settings)"

  log_step "Usuario: $SYS_USER"
  if user_exists "$SYS_USER"; then
    user_add_group "$SYS_USER" wheel
    log_ok "Ya existe $SYS_USER"
  else
    run useradd -m -G wheel -s /bin/bash -- "$SYS_USER"
    log_ok "Creado $SYS_USER"
  fi

  log_step "sudo para el grupo wheel"
  write_file /etc/sudoers.d/10-wheel 440 <<<'%wheel ALL=(ALL:ALL) ALL'
  ((DRY_RUN)) || visudo -cqf /etc/sudoers.d/10-wheel || die "sudoers.d/10-wheel no es válido"

  log_step "Contraseñas"
  _set_password root
  _set_password "$SYS_USER"
}

# _set_password USUARIO — Aplica PASSWORD_HASH si es distinto del actual.
_set_password() {
  local user=$1
  if [[ $(getent shadow "$user" | cut -d: -f2) == "$PASSWORD_HASH" ]]; then
    log_ok "Contraseña de $user ya aplicada"
    return 0
  fi
  run chpasswd -e <<<"$user:$PASSWORD_HASH"
  log_ok "Contraseña de $user aplicada"
}
