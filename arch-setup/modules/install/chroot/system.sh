#!/usr/bin/env bash
# desc: Zona horaria, reloj, locale, teclado de consola y hostname

module_run() {
  log_step "Zona horaria: $TIMEZONE"
  local zone="/usr/share/zoneinfo/$TIMEZONE"
  [[ -f $zone ]] || die "Zona horaria inválida: $TIMEZONE"
  if [[ $(readlink /etc/localtime 2>/dev/null) != "$zone" ]]; then
    run ln -sf "$zone" /etc/localtime
  fi
  [[ -f /etc/adjtime ]] || run hwclock --systohc

  log_step "Locale: $LOCALE"
  ensure_uncommented /etc/locale.gen "$LOCALE ${LOCALE##*.}"
  if ((FILE_CHANGED)) || [[ ! -f /usr/lib/locale/locale-archive ]]; then
    run_quiet locale-gen
  fi
  write_file /etc/locale.conf <<<"LANG=$LOCALE"

  log_step "Teclado de consola: $KEYMAP"
  write_file /etc/vconsole.conf <<<"KEYMAP=$KEYMAP"

  log_step "Hostname: $SYS_HOSTNAME"
  write_file /etc/hostname <<<"$SYS_HOSTNAME"
}
