#!/usr/bin/env bash
# desc: rate-mirrors y el script mirror-update (mirrors más rápidos)

module_run() {
  log_step "rate-mirrors"
  pkg_install rate-mirrors

  log_step "Script /usr/local/bin/mirror-update"
  install_file "$CONFIG_DIR/files/mirror-update" /usr/local/bin/mirror-update 755

  # Solo se ordenan los mirrors la primera vez; después, cuando tú quieras.
  if ((FILE_CHANGED)); then
    log_step "Ordenando mirrors (tarda un poco)"
    run /usr/local/bin/mirror-update || log_warn "mirror-update falló; se mantienen los mirrors actuales"
  else
    log_ok "Ya instalado. Para reordenar: mirror-update"
  fi
}
