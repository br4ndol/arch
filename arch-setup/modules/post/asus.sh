#!/usr/bin/env bash
# desc: ASUS ROG: asusctl, rog-control-center y power-profiles-daemon
#
# Ver ArchLinux2/gaming.md (secciones CPU y Asus). En una VM se instala igual;
# asusd simplemente no hace nada sin hardware ASUS.

module_run() {
  log_step "Perfiles de energía"
  pkg_install power-profiles-daemon
  service_enable --now power-profiles-daemon.service

  log_step "asusctl y rog-control-center"
  pkg_install asusctl rog-control-center
}
