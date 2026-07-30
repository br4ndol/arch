#!/bin/bash
set -e

# =====================================================================
# Script de Bootstrap para Arch Linux + CachyOS v3
# Ejecutar en el entorno Live de la ISO de Arch Linux.
# =====================================================================

# --- Colores para mensajes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

msg() { echo -e "${YELLOW}[BOOTSTRAP]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- Preguntas interactivas al usuario ---
msg "============================================="
msg "Configuración inicial del sistema"
msg "============================================="

# Preguntar por las particiones
read -rp "Partición para /efi (Ingrese el nombre como vda1 o nvme0n1p1): " PART_EFI
read -rp "Partición para / (raíz, ej: nvme0n1p2): " PART_ROOT

# Preguntar por la contraseña (para root y usuario)
read -rsp "Contraseña para root y usuario (no se mostrará): " PASSWORD
echo  # Salto de línea después de la contraseña

# Preguntar por el usuario y hostname (opcional, con valores por defecto)
read -rp "Nombre de usuario [br4ndol]: " TARGET_USER
TARGET_USER="${TARGET_USER:-br4ndol}"  # Valor por defecto: br4ndol

read -rp "Hostname [arx-ArchLinux]: " HOST_NAME
HOST_NAME="${HOST_NAME:-arx-ArchLinux}"  # Valor por defecto: arx-ArchLinux

# Zona horaria (opcional, con valor por defecto)
read -rp "Zona horaria [America/Santo_Domingo]: " TIME_ZONE
TIME_ZONE="${TIME_ZONE:-America/Santo_Domingo}"

# URL del repositorio (opcional, con valor por defecto)
read -rp "URL del repositorio [https://github.com/br4ndol/arch.git]: " REPO_URL
REPO_URL="${REPO_URL:-https://github.com/br4ndol/arch.git}"

# --- Variables de Configuración (ahora dinámicas) ---
LOCALE="en_US.UTF-8 UTF-8"  # Inglés (fijo, como pediste)

msg "============================================="
msg "Configuración aplicada:"
msg "Partición EFI: /dev/$PART_EFI"
msg "Partición Raíz: /dev/$PART_ROOT"
msg "Usuario: $TARGET_USER"
msg "Hostname: $HOST_NAME"
msg "Zona horaria: $TIME_ZONE"
msg "Repositorio: $REPO_URL"
msg "============================================="

#
#   Paso 2
#

# --- 1. Verificaciones Iniciales ---
msg "Verificando entorno de instalación..."

# Verificar conexión a internet
if ! ping -c 1 archlinux.org &>/dev/null; then
    error "No hay conexión a internet. Conéctate vía Ethernet o iwctl antes de continuar."
    exit 1
fi
success "Conexión a internet activa."

# Verificar modo UEFI
if [ ! -d "/sys/firmware/efi" ]; then
    error "El sistema no inició en modo UEFI. Este script requiere arranque UEFI."
    exit 1
fi
success "Sistema iniciado en modo UEFI."

# --- 2. Montar Particiones ---
msg "Preparando y montando particiones..."

# Desmontar limpiamente cualquier montaje previo en /mnt
umount -R /mnt 2>/dev/null || true

# Montar partición Raíz (ext4)
if [ -b "/dev/$PART_ROOT" ]; then
    mount "/dev/$PART_ROOT" /mnt
    success "Partición raíz (/dev/$PART_ROOT) montada en /mnt."
else
    error "No se encontró el dispositivo de la partición raíz: /dev/$PART_ROOT"
    exit 1
fi

# Crear directorio efi y montar partición EFI (FAT32)
if [ -b "/dev/$PART_EFI" ]; then
    mkdir -p /mnt/efi
    mount "/dev/$PART_EFI" /mnt/efi
    success "Partición EFI (/dev/$PART_EFI) montada en /mnt/efi."
else
    error "No se encontró el dispositivo de la partición EFI: /dev/$PART_EFI"
    exit 1
fi

#
#   Paso 3
#

# --- 3. Inyección de CachyOS v3 en la ISO ---
msg "Configurando llaves y repositorios de CachyOS v3 en la ISO..."

# Importar y firmar llaves GPG de CachyOS
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

# Descargar e instalar paquetes de llaves y mirrorlists oficiales
msg "Descargar e instalar paquetes de llaves y mirrorlists de CachyOS..."
pacman -U --noconfirm \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst'

# Configurar soporte para arquitectura x86_64_v3
msg "Configurar soporte para arquitectura x86_64_v3..."
sed -i 's/^Architecture = .*/Architecture = x86_64 x86_64_v3/' /etc/pacman.conf

# Insertar repositorios de CachyOS v3 justo ARRIBA de [core] para darles máxima prioridad
msg "Insertar repositorios de CachyOS v3 justo ARRIBA de [core] para darles máxima prioridad..."
if ! grep -q "cachyos-v3" /etc/pacman.conf; then
    sed -i '/^\[core\]/i \
# CachyOS optimized repos - x86-64-v3\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n' /etc/pacman.conf
fi

# Sincronizar bases de datos de pacman
msg "Sincronizando bases de datos de pacman..."
pacman -Syy
success "Repositorios de CachyOS v3 inyectados arriba de los repositorios oficiales."

#
#   Paso 4
#

# --- 4. Instalación Base con pacstrap ---
msg "Ejecutando pacstrap con el Kernel CachyOS-bore y paquetes base..."

pacstrap -K /mnt \
    base base-devel \
    cachyos-v3/linux-cachyos-bore \
    cachyos-v3/linux-cachyos-bore-headers \
    git networkmanager sudo efibootmgr nano

success "Sistema base instalado mediante pacstrap."

#
#   Paso 5
#

# --- 5. Generar fstab ---
msg "Generando archivo /etc/fstab para el nuevo sistema..."
genfstab -U /mnt >> /mnt/etc/fstab

# Verificar que el archivo fstab se generó correctamente
if [ -f "/mnt/etc/fstab" ]; then
    success "Archivo /etc/fstab generado correctamente."
    msg "Contenido de /etc/fstab:"
    cat /mnt/etc/fstab
else
    error "No se pudo generar /etc/fstab. Verifica que las particiones estén montadas correctamente."
    exit 1
fi

#
#   Paso 6
#

# --- 6. Configuración dentro de chroot ---
msg "Iniciando configuración en chroot (/mnt)..."

arch-chroot /mnt /bin/bash <<'EOF'
set -e

# --- Configurar Zona Horaria ---
msg "Configurando zona horaria a $TIME_ZONE..."
ln -sf /usr/share/zoneinfo/"$TIME_ZONE" /etc/localtime
hwclock --systohc
success "Zona horaria configurada."

# --- Configurar Locales (Inglés) ---
msg "Configurando locales en_US.UTF-8..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
success "Locales configurados."

# --- Configurar Hostname ---
msg "Configurando hostname a $HOST_NAME..."
echo "$HOST_NAME" > /etc/hostname
success "Hostname configurado."

# --- Instalar paquetes de CachyOS v3 en el nuevo sistema ---

# Importar y firmar llaves GPG de CachyOS
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

msg "Instalando paquetes de CachyOS v3 (keyring y mirrorlists)..."
pacman -U --noconfirm \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst'

# --- Configurar pacman.conf en el nuevo sistema ---
msg "Configurando repositorios de CachyOS v3 en el nuevo sistema..."
sed -i 's/^Architecture = .*/Architecture = x86_64 x86_64_v3/' /etc/pacman.conf

# Insertar repositorios de CachyOS v3 ARRIBA de [core]
if ! grep -q "cachyos-v3" /etc/pacman.conf; then
    sed -i '/^\[core\]/i \
# CachyOS optimized repos - x86-64-v3\n[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n' /etc/pacman.conf
fi

# Habilitar repositorio [multilib]
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# Sincronizar bases de datos de pacman
pacman -Syy

success "Repositorios de CachyOS v3 configurados en el nuevo sistema."

# --- Crear Usuario Principal ---
msg "Creando usuario $TARGET_USER..."
if ! id "$TARGET_USER" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "$TARGET_USER"
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 0440 /etc/sudoers.d/wheel
    echo "$TARGET_USER:$PASSWORD" | chpasswd
    echo "root:$PASSWORD" | chpasswd
    success "Usuario $TARGET_USER creado con permisos sudo."
else
    msg "El usuario $TARGET_USER ya existe."
fi

# --- Habilitar NetworkManager ---
msg "Habilitando NetworkManager..."
systemctl enable NetworkManager.service
success "NetworkManager habilitado."

# --- Clonar repositorio arch-setup ---
msg "Clonando repositorio $REPO_URL..."
HOME_DIR="/home/$TARGET_USER"
if [ ! -d "$HOME_DIR/arch" ]; then
    git clone "$REPO_URL" "$HOME_DIR/arch"
    chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR/arch"
    success "Repositorio clonado en $HOME_DIR/arch."
else
    msg "El repositorio ya existe en $HOME_DIR/arch."
fi

EOF

success "🎉 Configuración en chroot completada con éxito."

#
#   Paso 7
#

# --- 7. Finalización y desmontaje ---
msg "Desmontando particiones..."
umount -R /mnt 2>/dev/null || true
success "Particiones desmontadas correctamente."

msg "============================================="
msg "¡Bootstrap completado con éxito!"
msg "============================================="
msg "Pasos siguientes:"
msg "1. Reinicia el sistema: 'reboot'"
msg "2. Inicia sesión con el usuario: $TARGET_USER (contraseña: $PASSWORD)"
msg "3. Ejecuta el script de configuración:"
msg "   cd ~/arch && sudo ./setup.sh"
msg "============================================="