#!/usr/bin/env bash
# desc: cmdline, UKI principal y de respaldo, y sus entradas de arranque EFI (EFISTUB)
#
# Ver ArchLinux2/kernel.md. Sin bootloader: el firmware arranca el UKI.
#
# Genera dos UKI (preset con 'default' y 'fallback', cada uno con su entrada EFI).
# Solo en una máquina virtual deja además una copia del principal en la ruta de
# respaldo UEFI (\EFI\BOOT\BOOTX64.EFI), porque VirtualBox olvida las entradas;
# un post hook de mkinitcpio la mantiene al día. En hardware real no: el
# firmware (ASUS/AMI) crea solo una tercera entrada "UEFI OS" para esa ruta.

POST_HOOK=/etc/initcpio/post/arch-setup-uki-fallback
BOOTX64=/efi/EFI/BOOT/BOOTX64.EFI

module_run() {
  local uki="/efi/EFI/Linux/arch-$KERNEL.efi" uki_fb="/efi/EFI/Linux/arch-$KERNEL-fallback.efi"
  local root_uuid rebuild=0

  is_mounted /efi || die "/efi no está montada"
  [[ -f /boot/vmlinuz-$KERNEL ]] || die "No existe /boot/vmlinuz-$KERNEL (¿se instaló el kernel?)"

  log_step "cmdline del kernel"
  root_uuid=$(findmnt -no UUID /)
  [[ -n $root_uuid ]] || die "No se pudo obtener el UUID de /"
  write_file /etc/kernel/cmdline <<<"root=UUID=$root_uuid rw"
  ((FILE_CHANGED)) && rebuild=1

  log_step "Preset de mkinitcpio (UKI)"
  render_template "$CONFIG_DIR/files/mkinitcpio.preset" "/etc/mkinitcpio.d/$KERNEL.preset"
  ((FILE_CHANGED)) && rebuild=1
  [[ -d /efi/EFI/Linux ]] || run mkdir -p /efi/EFI/Linux

  log_step "Copia de respaldo en \\EFI\\BOOT\\BOOTX64.EFI (solo en VM)"
  if systemd-detect-virt --quiet --vm; then
    # Se instala antes de generar el UKI: mkinitcpio la mantiene al día desde ahora.
    render_template "$CONFIG_DIR/files/uki-fallback.hook" "$POST_HOOK" 755
  else
    _remove_bootx64
  fi

  log_step "UKI principal y de respaldo"
  if ((rebuild)) || [[ ! -f $uki || ! -f $uki_fb ]]; then
    run mkinitcpio -p "$KERNEL"
  else
    log_ok "Ya generados: $uki y $uki_fb"
  fi
  # Los initramfs clásicos que dejó pacstrap ya no se usan.
  local img
  for img in /boot/initramfs-"$KERNEL"*.img; do
    if [[ -e $img ]]; then run rm -f -- "$img"; fi
  done

  # Por si el UKI ya existía y no se regeneró (el hook solo actúa al regenerar).
  if [[ -f $POST_HOOK && -f $uki ]] && ! same_content "$uki" "$BOOTX64"; then
    run mkdir -p -- "${BOOTX64%/*}"
    run cp -f -- "$uki" "$BOOTX64"
    log_ok "Copiado a $BOOTX64"
  fi

  log_step "Entradas de arranque EFI"
  # efibootmgr pone la última creada al principio: la principal va al final.
  _ensure_uefi_entry "Arch Linux (${KERNEL#linux-} fallback)" "\\EFI\\Linux\\arch-$KERNEL-fallback.efi"
  _ensure_uefi_entry "Arch Linux (${KERNEL#linux-})" "\\EFI\\Linux\\arch-$KERNEL.efi"
}

# _remove_bootx64 — En hardware real: quita el hook y la copia si los puso una
# versión anterior (la ESP la formatea el script, así que BOOTX64.EFI es nuestro).
_remove_bootx64() {
  local partuuid entries n
  if [[ -f $POST_HOOK ]]; then run rm -f -- "$POST_HOOK"; fi
  if [[ -f $BOOTX64 ]]; then
    run rm -f -- "$BOOTX64"
    run rmdir --ignore-fail-on-non-empty -- "${BOOTX64%/*}"
    log_ok "Quitado $BOOTX64"
  else
    log_ok "Hardware real: no hace falta"
  fi
  # La entrada "UEFI OS" que el firmware creó para esa ruta sigue en la NVRAM
  # aunque se reinstale (formatear no cambia el PARTUUID): se borra también.
  partuuid=$(lsblk -no PARTUUID "$(findmnt -no SOURCE /efi)")
  entries=$(efibootmgr -v 2>/dev/null | awk -v p="${partuuid,,}" \
    'tolower($0) ~ /\\efi\\boot\\bootx64\.efi/ && index(tolower($0), p) { print substr($1, 5, 4) }') || entries=''
  while read -r n; do
    if [[ -n $n ]]; then
      run efibootmgr -q -b "$n" -B
      log_ok "Borrada la entrada Boot$n (UEFI OS -> BOOTX64.EFI)"
    fi
  done <<<"$entries"
}

# _ensure_uefi_entry ETIQUETA LOADER — Crea la entrada si no existe una con esa
# etiqueta apuntando a esta ESP y a este loader. Si hay entradas viejas con la
# misma etiqueta, las borra antes (así no se duplican).
_ensure_uefi_entry() {
  local label=$1 loader=$2 dev disk part partuuid entries n
  dev=$(findmnt -no SOURCE /efi)
  disk="/dev/$(lsblk -no PKNAME "$dev")"
  part=$(lsblk -no PARTN "$dev")
  partuuid=$(lsblk -no PARTUUID "$dev")

  entries=$(efibootmgr -v 2>/dev/null | awk -v l="$label" 'index($0, l)') || entries=''
  if [[ -n $entries && $(wc -l <<<"$entries") -eq 1 &&
    ${entries,,} == *"${partuuid,,}"* && ${entries,,} == *"${loader,,}"* ]]; then
    log_ok "Ya existe: $label"
    return 0
  fi

  while read -r n; do
    if [[ -n $n ]]; then run efibootmgr -q -b "$n" -B; fi
  done < <(awk '{ print substr($1, 5, 4) }' <<<"$entries")
  run efibootmgr -q --create --disk "$disk" --part "$part" --label "$label" --loader "$loader"
  log_ok "Creada: $label -> $loader"
}
