#!/usr/bin/env bash
# desc: Swap comprimida en RAM con zram-generator (8 GiB, lz4)

module_run() {
  local zram_changed=0

  log_step "zram-generator"
  pkg_install zram-generator
  write_file /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = 8192
compression-algorithm = lz4
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
  log_ok "zram listo (compruébalo con: swapon --show)"
}
