#!/usr/bin/env bash
# desc: Drivers de vídeo según GPU (nvidia-hybrid | intel | none)
#
# Ver ArchLinux2/Video Drivers.md. Con GPU=none (máquina virtual) no hace nada.

module_run() {
  # La respuesta de install.sh no se guarda en el sistema; si no está en
  # settings, se vuelve a preguntar (con la misma autodetección).
  if [[ -z ${GPU:-} ]]; then
    log_info "nvidia-hybrid = Intel + Nvidia (portátil) · intel = solo Intel · none = ninguno (VM)"
    GPU=$(detect_gpu)
    choose "¿Qué drivers instalar?" GPU nvidia-hybrid intel none
  fi

  case $GPU in
    none) log_info "GPU=none: no se instalan drivers de vídeo" ;;
    intel) _intel ;;
    nvidia-hybrid)
      _intel
      _nvidia
      ;;
    *) die "GPU desconocida: '$GPU' (nvidia-hybrid | intel | none)" ;;
  esac
}

_intel() {
  log_step "Intel"
  install_list "$CONFIG_DIR/packages/gpu-intel.list"
}

_nvidia() {
  local rebuild=0 m

  log_step "Nvidia"
  install_list "$CONFIG_DIR/packages/gpu-nvidia.list"
  pkg_install "$KERNEL-nvidia-open"

  log_step "Servicios"
  service_enable --now switcheroo-control.service nvidia-powerd.service
  # Se ejecutan al suspender/reanudar: solo se habilitan, nunca se arrancan.
  # nvidia-hibernate no: sin swap en disco no hay hibernación.
  service_enable nvidia-suspend.service nvidia-resume.service

  log_step "Hook de pacman (regenera el UKI al actualizar el driver)"
  render_template "$CONFIG_DIR/files/nvidia.hook" /etc/pacman.d/hooks/nvidia.hook

  log_step "Módulos en el initramfs"
  for m in i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    mkinitcpio_add MODULES "$m"
    if ((FILE_CHANGED)); then rebuild=1; fi
  done

  if ((rebuild)); then
    uki_rebuild
  else
    log_ok "UKI al día"
  fi
}
