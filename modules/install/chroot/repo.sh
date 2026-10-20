#!/usr/bin/env bash
# desc: Copia el repo a ~/arch del usuario, listo para ejecutar post.sh al arrancar
#
# Se copia tal cual (con .git si vino de un git clone, para poder hacer git pull)
# y con settings.local.conf, así post.sh no vuelve a preguntar la GPU. Lo único
# que no viaja es PASSWORD_HASH: solo hace falta aquí y no debe quedar en el HOME.

REPO_DIR=arch

module_run() {
  local user=$SYS_USER home dst
  home=$(user_home "$user")
  [[ -n $home ]] || die "No encuentro el HOME de $user"
  dst="$home/$REPO_DIR"

  log_step "Copia del repo en $dst"
  run rm -rf -- "$dst"
  run mkdir -p -- "$dst"
  run cp -a -- "$ROOT_DIR/." "$dst/"
  run rm -f -- "$dst/config/settings.local.conf"
  if [[ -f $CONFIG_DIR/settings.local.conf ]]; then
    awk '!/^PASSWORD_HASH=/' "$CONFIG_DIR/settings.local.conf" | write_file "$dst/config/settings.local.conf" 600
  fi
  run chown -R -- "$user:" "$dst"
  log_ok "Tras reiniciar: cd ~/$REPO_DIR && sudo ./post.sh"
}
