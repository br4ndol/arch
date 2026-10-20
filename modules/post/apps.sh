#!/usr/bin/env bash
# desc: Apps: Brave Origin, VSCodium y soporte de AppImages (fuse2 + Gear Lever)

module_run() {
  log_step "Paquetes y apps"
  install_list "$CONFIG_DIR/packages/apps.list"
}
