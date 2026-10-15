#!/usr/bin/env bash
# desc: Bluetooth con BlueZ (ArchLinux2/gnome-bluetooth.md)

module_run() {
  log_step "BlueZ"
  pkg_install bluez bluez-utils
  service_enable --now bluetooth.service
}
