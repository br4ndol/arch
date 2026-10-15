#!/usr/bin/env bash
# desc: Mantenimiento ligero: TRIM semanal del SSD y limpieza de la caché de pacman
#
# Nada queda corriendo: fstrim.timer despierta una vez por semana y termina;
# paccache lo lanza un hook de pacman después de cada operación.

module_run() {
  log_step "TRIM semanal (fstrim.timer)"
  service_enable --now fstrim.timer

  log_step "Caché de pacman (hook de paccache)"
  pkg_install pacman-contrib
  install_file "$CONFIG_DIR/files/paccache.hook" /etc/pacman.d/hooks/paccache.hook
}
