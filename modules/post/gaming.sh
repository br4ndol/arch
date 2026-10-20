#!/usr/bin/env bash
# desc: Gaming (opcional): Steam, Proton-CachyOS, Faugus, gamemode, MangoHud y NTSYNC
#
# Ver ArchLinux2/gaming.md. post.sh pregunta al principio si se instala, salvo
# que GAMING (settings.conf) valga yes o no. Fuera a propósito: cpupower (choca
# con power-profiles-daemon; gamemode ya sube el rendimiento al jugar) y
# nvidia-smi -pm 1 (no deja dormir a la Nvidia y gasta batería).

module_run() {
  local user=$SYS_USER home missing
  if [[ ${GAMING:-no} != yes ]]; then
    log_info "GAMING=${GAMING:-no}: se omite"
    return 0
  fi
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"

  # Steam y Proton piden un driver Vulkan de 64 y 32 bits. Sin ninguno (GPU=none)
  # pacman elegiría uno cualquiera, quizá el de Nvidia: mejor no seguir.
  missing=$(pacman -T vulkan-driver lib32-vulkan-driver) || true
  if [[ -n $missing ]]; then
    log_warn "No hay driver Vulkan ($(tr '\n' ' ' <<<"$missing")): ejecuta antes drivers con GPU=intel o nvidia-hybrid. Se omite gaming"
    return 0
  fi

  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/gaming.list"

  log_step "gamemode"
  user_add_group "$user" gamemode
  user_install_file "$user" "$CONFIG_DIR/files/gamemode.ini" "$home/.config/gamemode.ini"

  log_step "NTSYNC (sincronización de Proton en el kernel)"
  write_file /etc/modules-load.d/ntsync.conf <<<'ntsync'
  if [[ ! -e /dev/ntsync ]] && systemd_running; then
    run modprobe ntsync
  fi
}
