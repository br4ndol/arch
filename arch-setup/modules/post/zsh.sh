#!/usr/bin/env bash
# desc: zsh con Starship, plugins y fzf-tab, para el usuario y para root
#
# Ver ArchLinux2/zshell.md. Root usa su propia copia de la configuración.

FZF_TAB_URL=https://github.com/Aloxaf/fzf-tab

module_run() {
  local user=$SYS_USER home config
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"

  log_step "Paquetes"
  install_list "$CONFIG_DIR/packages/zsh.list"

  # config.zsh lleva {{KERNEL}} (alias kernel-update).
  config="$RUN_TMPDIR/config.zsh"
  render_template "$CONFIG_DIR/files/zsh/config.zsh" - >"$config"

  log_step "Configuración de $user"
  user_mkdir "$user" "$home/.config/zsh" "$home/.cache/zsh" "$home/.local/state/zsh" "$home/.local/share/zsh/plugins"
  user_install_file "$user" "$config" "$home/.config/zsh/config.zsh"
  user_install_file "$user" "$CONFIG_DIR/files/zsh/zshrc" "$home/.zshrc"
  [[ -f $home/.local/state/zsh/history ]] || user_write_file "$user" "$home/.local/state/zsh/history" 600 </dev/null
  if [[ ! -d $home/.local/share/zsh/plugins/fzf-tab/.git ]]; then
    retry 3 5 run_as_user "$user" git clone --depth 1 "$FZF_TAB_URL" "$home/.local/share/zsh/plugins/fzf-tab"
  fi

  log_step "Shell de $user"
  if [[ $(getent passwd "$user" | cut -d: -f7) != */zsh ]]; then
    run usermod -s /bin/zsh -- "$user"
    log_ok "Shell cambiada a zsh (efectiva al volver a iniciar sesión)"
  else
    log_ok "Ya usa zsh"
  fi

  log_step "Configuración de root"
  local d
  for d in /root/.config/zsh /root/.cache/zsh /root/.local/state/zsh /root/.local/share/zsh/plugins; do
    [[ -d $d ]] || run install -d -m 700 -- "$d"
  done
  install_file "$config" /root/.config/zsh/config.zsh 644
  install_file "$CONFIG_DIR/files/zsh/zshrc-root" /root/.zshrc 644
  if [[ ! -d /root/.local/share/zsh/plugins/fzf-tab/.git ]]; then
    retry 3 5 git clone --depth 1 "$FZF_TAB_URL" /root/.local/share/zsh/plugins/fzf-tab
  fi
}
