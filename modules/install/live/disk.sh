#!/usr/bin/env bash
# desc: Formatea ESP (FAT32) y raíz (ext4) y las monta en /mnt y /mnt/efi
#
# Las particiones las creas tú antes con cfdisk (ver ArchLinux2/Esquema.md).
# Si ya están montadas tal cual (p. ej. al repetir tras un fallo posterior),
# no vuelve a formatear.

TARGET=/mnt

module_run() {
  [[ -n $ESP_PART && -n $ROOT_PART ]] || die "Faltan ESP_PART/ROOT_PART (módulo settings)"
  [[ $ESP_PART != "$ROOT_PART" ]] || die "ESP y raíz no pueden ser la misma partición"
  is_block_device "$ESP_PART" || die "No existe $ESP_PART"
  is_block_device "$ROOT_PART" || die "No existe $ROOT_PART"

  if _mounted_from "$TARGET" "$ROOT_PART" && _mounted_from "$TARGET/efi" "$ESP_PART"; then
    log_ok "Ya montadas: $ROOT_PART en $TARGET y $ESP_PART en $TARGET/efi (no se formatea)"
    return 0
  fi

  is_mounted "$TARGET" && die "$TARGET ya tiene algo montado; desmóntalo con: umount -R $TARGET"
  local p
  for p in "$ESP_PART" "$ROOT_PART"; do
    [[ -z $(findmnt -rno TARGET --source "$p" 2>/dev/null) ]] || die "$p está montada; desmóntala primero"
  done
  _warn_if_not_esp

  log_step "Formateando"
  lsblk -po NAME,SIZE,FSTYPE,LABEL "$ESP_PART" "$ROOT_PART" >&2
  if ! ((DRY_RUN)); then
    confirm_dangerous "Se BORRARÁ todo el contenido de $ESP_PART y $ROOT_PART" FORMATEAR ||
      die "Cancelado por el usuario"
  fi
  run mkfs.fat -F 32 -n ESP "$ESP_PART"
  run mkfs.ext4 -F -L root "$ROOT_PART"

  log_step "Montando"
  run mount "$ROOT_PART" "$TARGET"
  # fmask/dmask: la ESP solo legible por root.
  run mount --mkdir -o fmask=0077,dmask=0077 "$ESP_PART" "$TARGET/efi"
  log_ok "$ROOT_PART -> $TARGET, $ESP_PART -> $TARGET/efi"
}

# _mounted_from PUNTO PARTICION
_mounted_from() {
  [[ $(findmnt -rno SOURCE --mountpoint "$1" 2>/dev/null) == "$2" ]]
}

# El firmware busca el UKI en particiones de tipo "EFI System".
_warn_if_not_esp() {
  local type
  type=$(lsblk -no PARTTYPE "$ESP_PART" 2>/dev/null) || true
  if [[ ${type,,} != c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]]; then
    log_warn "$ESP_PART no es de tipo 'EFI System' (cámbialo en cfdisk -> Type)"
    confirm "¿Continuar de todos modos?" n || die "Cancelado"
  fi
}
