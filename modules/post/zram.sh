#!/usr/bin/env bash
# desc: Swap comprimida en RAM con zram-generator (8 GiB, zstd) y zswap desactivado

module_run() {
  local zram_changed=0

  log_step "zram-generator"
  pkg_install zram-generator
  # zstd comprime más que lz4 (más RAM útil); en una CPU moderna la diferencia
  # de velocidad no se nota.
  write_file /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = 8192
compression-algorithm = zstd
swap-priority = 100
EOF
  zram_changed=$FILE_CHANGED

  log_step "sysctl para zram"
  write_file /etc/sysctl.d/99-zram.conf <<'EOF'
vm.swappiness=100
vm.page-cluster=0
EOF
  if ((FILE_CHANGED)) && systemd_running; then
    run_quiet sysctl --system
  fi

  if ((zram_changed)) && systemd_running; then
    log_step "Activando zram0"
    run swapoff /dev/zram0 2>/dev/null || true
    run systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
    run systemctl daemon-reload
    run systemctl start systemd-zram-setup@zram0.service
  fi

  # Con zram, zswap sobra: comprimiría las páginas dos veces.
  log_step "zswap desactivado (cmdline)"
  cmdline_add zswap.enabled=0
  if ((FILE_CHANGED)); then uki_rebuild; fi

  log_ok "zram listo (compruébalo con: swapon --show)"
}
