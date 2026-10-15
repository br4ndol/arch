#!/usr/bin/env bash
# desc: NetworkManager con iwd como backend wifi (ArchLinux2/networkmanager-iwd.md)

module_run() {
  log_step "Backend wifi: iwd"
  write_file /etc/NetworkManager/conf.d/wifi_backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

  log_step "Servicios"
  # NetworkManager arranca iwd por su cuenta; los demás gestores sobran.
  service_disable wpa_supplicant systemd-networkd dhcpcd
  service_enable NetworkManager
}
