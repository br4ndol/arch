#!/usr/bin/env bash
# desc: yay, el helper de AUR (precompilado desde chaotic-aur)

module_run() {
  log_step "${AUR_HELPER:-yay}"
  aur_ensure_helper
  log_ok "Helper AUR listo: $(aur_helper || echo "${AUR_HELPER:-yay}")"
}
