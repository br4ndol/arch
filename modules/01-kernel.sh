#!/bin/bash
set -e

# =====================================================================
# Módulo: 01-kernel.sh
# Descripción: Instala y configura el kernel linux-cachyos-bore,
#              configura el archivo preset para UKI y crea la entrada UEFI.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./01-kernel.sh'."
    exit 1
fi

# --- Variables ---
KERNEL_PKG="linux-cachyos-bore"
HEADERS_PKG="linux-cachyos-bore-headers"
PRESET_FILE="/etc/mkinitcpio.d/linux-cachyos-bore.preset"
UKI_PATH="/efi/EFI/Linux/arch-linux-cachyos-bore.efi"
BOOT_LABEL="Arch Linux (cachyos-bore)"

# --- 1. Verificación de Estado Real ---
msg "Verificando si el kernel ya está configurado..."

kernel_instalado=0
uki_existe=0
uefi_configurado=0

if paquete_instalado "$KERNEL_PKG" && paquete_instalado "$HEADERS_PKG"; then
    kernel_instalado=1
fi

if [ -f "$UKI_PATH" ]; then
    uki_existe=1
fi

if efibootmgr | grep -q "$BOOT_LABEL"; then
    uefi_configurado=1
fi

# Si todo está listo, omitimos el script
if [ $kernel_instalado -eq 1 ] && [ $uki_existe -eq 1 ] && [ $uefi_configurado -eq 1 ]; then
    success "El kernel ya está instalado, la UKI existe y la entrada UEFI está configurada. ¡Módulo omitido!"
    exit 0
fi

# --- 2. Verificaciones de Seguridad Previas ---
if [ ! -d "/efi" ]; then
    error "El directorio /efi no existe. ¿Está montada tu partición ESP?"
    exit 1
fi

# --- Validar que el sistema sea UEFI ---
if [ ! -d "/sys/firmware/efi" ]; then
    error "El sistema no está en modo UEFI. Este módulo solo funciona en UEFI."
    exit 1
fi

# --- Validar que la partición EFI esté montada en /efi ---
if [ ! -d "/efi" ]; then
    error "La partición EFI no está montada en /efi. Montala manualmente y vuelve a ejecutar el script."
    exit 1
fi

# --- 3. Instalación de Paquetes ---
if [ $kernel_instalado -eq 0 ]; then
    msg "Instalando kernel cachyos-bore y headers..."
    # Intentamos instalar desde la rama cachyos-v3 especificada
    if ! pacman -S --needed --noconfirm "cachyos-v3/$KERNEL_PKG" "cachyos-v3/$HEADERS_PKG"; then
        error "No se pudo instalar desde cachyos-v3. Intentando instalación estándar..."
        instalar_paquete "$KERNEL_PKG"
        instalar_paquete "$HEADERS_PKG"
    fi
else
    msg "Paquetes del kernel ya instalados."
fi

# --- Regenerar todas las imágenes initramfs ---
msg "Regenerando imágenes initramfs..."
if ! mkinitcpio -P; then
    error "Falló mkinitcpio -P. Verifica que el kernel esté instalado correctamente."
    exit 1
fi
success "Imágenes initramfs regeneradas."


# --- 4. Configuración del Archivo Preset (UKI) ---
if [ -f "$PRESET_FILE" ]; then
    msg "Configurando archivo preset: $PRESET_FILE..."
    
    # Asegurar que solo se compile la imagen 'default'
    sed -i "s/^PRESETS=.*/PRESETS=('default')/" "$PRESET_FILE"
    
    # Descomentar/configurar la ruta de la UKI
    if grep -q "default_uki" "$PRESET_FILE"; then
        sed -i "s|^#*default_uki=.*|default_uki=\"$UKI_PATH\"|" "$PRESET_FILE"
    else
        echo "default_uki=\"$UKI_PATH\"" >> "$PRESET_FILE"
    fi
    
    # Descomentar/configurar default_options vacío (quitar splash de systemd para Plymouth)
    if grep -q "default_options" "$PRESET_FILE"; then
        sed -i "s|^#*default_options=.*|default_options=\"\"|" "$PRESET_FILE"
    else
        echo 'default_options=""' >> "$PRESET_FILE"
    fi
    
    success "Archivo preset configurado correctamente."
else
    error "No se encontró el archivo preset en $PRESET_FILE"
    exit 1
fi

# --- 5. Generación de la UKI ---
msg "Generando la Unified Kernel Image (UKI)..."
if ! mkinitcpio -p "$KERNEL_PKG"; then
    error "Falló la generación de la UKI con mkinitcpio."
    exit 1
fi

# --- 6. Instalación en el Gestor de Kernels del Sistema ---
msg "Registrando kernel en el sistema..."
for k in /usr/lib/modules/*cachyos*bore*; do
    if [ -d "$k" ]; then
        k_ver="${k##*/}"
        msg "Añadiendo kernel versión: $k_ver"
        kernel-install add "$k_ver" "/usr/lib/modules/$k_ver/vmlinuz"
    fi
done

# --- 7. Creación de Entrada UEFI en la NVRAM ---
if [ $uefi_configurado -eq 0 ]; then
    msg "Creando entrada de arranque UEFI..."
    
    # Detectar automáticamente disco y partición de la ruta /efi
    ESP_DEV=$(findmnt -no SOURCE /efi)
    if [ -z "$ESP_DEV" ]; then
        error "No se pudo detectar el dispositivo montado en /efi."
        exit 1
    fi
    
    DISK="/dev/$(lsblk -no PKNAME "$ESP_DEV")"
    PART="$(lsblk -no PARTN "$ESP_DEV")"
    
    msg "Detectado disco: $DISK, partición: $PART"
    
    # Crear la entrada usando barras invertidas (\) requeridas por UEFI
    if efibootmgr --create --disk "$DISK" --part "$PART" --label "$BOOT_LABEL" --loader '\EFI\Linux\arch-linux-cachyos-bore.efi'; then
        success "Entrada UEFI creada con éxito."
    else
        error "Error al crear la entrada UEFI con efibootmgr."
        exit 1
    fi
else
    msg "La entrada UEFI '$BOOT_LABEL' ya existe."
fi

# --- 8. Verificación Final ---
msg "Verificando archivos generados en /efi/EFI/Linux/:"
ls -lh /efi/EFI/Linux/

msg "Entradas de arranque actuales:"
efibootmgr

success "🎉 ¡Módulo del Kernel completado y verificado correctamente!"