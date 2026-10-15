#!/usr/bin/env bash
# desc: cmdline, UKI con mkinitcpio y entrada de arranque EFI (EFISTUB)
#
# Ver ArchLinux2/kernel.md. Sin bootloader: el firmware arranca el UKI.
#
# Además del UKI y su entrada EFI, deja una copia en la ruta de respaldo UEFI
# (\EFI\BOOT\BOOTX64.EFI), que el firmware arranca si pierde la entrada. Un post
# hook de mkinitcpio la mantiene al día en cada actualización del kernel.

POST_HOOK=/etc/initcpio/post/arch-setup-uki-fallback
FALLBACK=/efi/EFI/BOOT/BOOTX64.EFI

module_run() {
  local uki="/efi/EFI/Linux/arch-$KERNEL.efi" root_uuid rebuild=0

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

  log_step "Copia de respaldo en \\EFI\\BOOT\\BOOTX64.EFI"
  # Se instala antes de generar el UKI: mkinitcpio la mantiene al día desde ahora.
  render_template "$CONFIG_DIR/files/uki-fallback.hook" "$POST_HOOK" 755

  log_step "UKI"
  if ((rebuild)) || [[ ! -f $uki ]]; then
    run mkinitcpio -p "$KERNEL"
  else
    log_ok "Ya generado: $uki"
  fi
  # Los initramfs clásicos que dejó pacstrap ya no se usan.
  local img
  for img in /boot/initramfs-"$KERNEL"*.img; do
    if [[ -e $img ]]; then run rm -f -- "$img"; fi
  done

  # Por si el UKI ya existía y no se regeneró (el hook solo actúa al regenerar).
  if [[ -f $uki ]] && ! same_content "$uki" "$FALLBACK"; then
    run mkdir -p -- "${FALLBACK%/*}"
    run cp -f -- "$uki" "$FALLBACK"
    log_ok "Copiado a $FALLBACK"
  fi

  log_step "Entrada de arranque EFI"
  _ensure_uefi_entry "Arch Linux (${KERNEL#linux-})" "\\EFI\\Linux\\arch-$KERNEL.efi"
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
