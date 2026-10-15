#!/usr/bin/env bash
# desc: Configs del usuario: copia config/files/home/ a su HOME (Ghostty, Fastfetch, GTK4…)
#
# config/files/home/ refleja el HOME: config/files/home/.config/ghostty/config.ghostty
# termina en ~/.config/ghostty/config.ghostty. Para añadir otra config, déjala ahí.

module_run() {
  local user=$SYS_USER home src base="$CONFIG_DIR/files/home"
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"

  log_step "config/files/home -> $home"
  while IFS= read -r -d '' src; do
    user_install_file "$user" "$src" "$home/${src#"$base"/}"
  done < <(find "$base" -type f -print0 | sort -z)
}
