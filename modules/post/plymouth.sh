#!/usr/bin/env bash
# desc: Arranque silencioso con Plymouth (tema bgrt) y cmdline quiet/splash
#
# Ver ArchLinux2/Plymouth.md y Video Drivers.md (parámetros del cmdline).

THEME=bgrt
CMDLINE_PARAMS=(quiet splash loglevel=3 systemd.show_status=false vt.global_cursor_default=0)

module_run() {
  local rebuild=0

  log_step "Plymouth"
  pkg_install plymouth

  log_step "Hook en mkinitcpio"
  mkinitcpio_add HOOKS plymouth systemd udev
  if ((FILE_CHANGED)); then rebuild=1; fi

  log_step "cmdline: ${CMDLINE_PARAMS[*]}"
  cmdline_add "${CMDLINE_PARAMS[@]}"
  if ((FILE_CHANGED)); then rebuild=1; fi

  log_step "Tema: $THEME"
  if [[ $(plymouth-set-default-theme 2>/dev/null) != "$THEME" ]]; then
    run plymouth-set-default-theme "$THEME"
    rebuild=1
  fi

  if ((rebuild)); then
    uki_rebuild
  else
    log_ok "UKI al día"
  fi
}
