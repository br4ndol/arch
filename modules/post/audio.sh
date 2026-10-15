#!/usr/bin/env bash
# desc: Audio con PipeWire (ArchLinux2/Audio.md)

module_run() {
  log_step "PipeWire"
  install_list "$CONFIG_DIR/packages/audio.list"

  log_step "Tiempo real para $SYS_USER"
  user_add_group "$SYS_USER" realtime

  log_step "Servicios de usuario"
  service_enable_global pipewire.socket pipewire-pulse.socket wireplumber.service
}
