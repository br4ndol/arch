#!/bin/bash
set -e

# =====================================================================
# Módulo: 05-zsh.sh
# Descripción: Instala ZSH, herramientas CLI, Starship, fzf-tab
#              y aplica la configuración del usuario y root.
# =====================================================================

# --- Importar utilidades ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/utils.sh"

# --- Validar que se ejecute como root ---
if [ "$(id -u)" -ne 0 ]; then
    error "Este módulo debe ejecutarse como root. Usa 'sudo ./05-zsh.sh'."
    exit 1
fi

# --- Detectar Usuario Objetivo ---
TARGET_USER="${SUDO_USER}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd)
fi

if [ -z "$TARGET_USER" ]; then
    error "No se pudo determinar el usuario normal del sistema."
    exit 1
fi

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
CONFIG_DIR="${SCRIPT_DIR}/../configs"

msg "Configurando ZSH para el usuario: $TARGET_USER ($TARGET_HOME)..."

# --- Lista de paquetes ---
PACKAGES=(
    "fastfetch" "git" "eza" "rate-mirrors" "zsh"
    "ttf-jetbrains-mono-nerd" "starship" "zsh-autosuggestions"
    "zsh-syntax-highlighting" "zsh-completions" "fzf" "zoxide"
)

# --- 1. Instalación de Paquetes ---
msg "Verificando e instalando paquetes de ZSH y herramientas..."
MISSING_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if ! paquete_instalado "$pkg"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    instalar_paquete "${MISSING_PKGS[@]}"
else
    msg "Todos los paquetes ya están instalados."
fi

# --- 2. Cambiar Shell por defecto a ZSH ---
msg "Verificando shell predeterminado para $TARGET_USER y root..."
if [ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != "/bin/zsh" ]; then
    chsh -s /bin/zsh "$TARGET_USER"
    success "Shell cambiado a ZSH para $TARGET_USER."
fi

if [ "$(getent passwd root | cut -d: -f7)" != "/bin/zsh" ]; then
    chsh -s /bin/zsh root
    success "Shell cambiado a ZSH para root."
fi

# --- 3. Instalar o actualizar fzf-tab (Usuario y Root) ---
install_fzf_tab() {
    local target_dir="$1"
    local user="$2"

    mkdir -p "$(dirname "$target_dir")"
    if [ -d "$target_dir/.git" ]; then
        msg "Actualizando fzf-tab en $target_dir..."
        git -C "$target_dir" pull --ff-only &>/dev/null || true
    else
        msg "Clonando fzf-tab en $target_dir..."
        git clone https://github.com/Aloxaf/fzf-tab "$target_dir"
    fi

    if [ "$user" != "root" ]; then
        chown -R "$user:$user" "$(dirname "$target_dir")"
    fi
}

install_fzf_tab "$TARGET_HOME/.local/share/zsh/plugins/fzf-tab" "$TARGET_USER"
install_fzf_tab "/root/.local/share/zsh/plugins/fzf-tab" "root"

# --- 4. Desplegar Archivos de Configuración ---
msg "Desplegando archivos de configuración..."

# Crear directorios necesarios
mkdir -p "$TARGET_HOME/.config/zsh"
mkdir -p "$TARGET_HOME/.config"
mkdir -p "$TARGET_HOME/.local/state/zsh"

# Copiar configuraciones desde configs/
cp -f "${CONFIG_DIR}/zsh/config.zsh" "$TARGET_HOME/.config/zsh/config.zsh"
cp -f "${CONFIG_DIR}/zsh/zshrc" "$TARGET_HOME/.zshrc"
cp -f "${CONFIG_DIR}/zsh/starship.toml" "$TARGET_HOME/.config/starship.toml"

# Crear archivo de historial de usuario
touch "$TARGET_HOME/.local/state/zsh/history"

# Configurar .zshrc para root apuntando dinámicamente al home del usuario
cat > /root/.zshrc <<EOF
[[ \$- != *i* ]] && return

source ${TARGET_HOME}/.config/zsh/config.zsh
EOF

# --- 5. Asignar Permisos y Propietarios ---
msg "Ajustando permisos y propietarios de archivos..."

chmod 644 "$TARGET_HOME/.zshrc" "$TARGET_HOME/.config/zsh/config.zsh" "$TARGET_HOME/.config/starship.toml"
chmod 600 "$TARGET_HOME/.local/state/zsh/history"
chmod 644 /root/.zshrc

# Asignar todo el contenido de ~/.config y ~/.local al usuario normal
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc"

# --- 6. Copiar configuraciones adicionales (btop, fastfetch, ghostty) ---
msg "Copiando configuraciones adicionales para $TARGET_USER..."

# btop
BTOP_CONF_SRC="${SCRIPT_DIR}/../configs/btop.conf"
BTOP_DIR="$TARGET_HOME/.config/btop"
mkdir -p "$BTOP_DIR"
if [ -f "$BTOP_CONF_SRC" ]; then
    cp -f "$BTOP_CONF_SRC" "$BTOP_DIR/"
    chown "$TARGET_USER:$TARGET_USER" "$BTOP_DIR/btop.conf"
    success "Configuración de btop copiada."
else
    error "No se encontró el archivo de configuración de btop en $BTOP_CONF_SRC"
    exit 1
fi

# fastfetch
FASTFETCH_DIR="$TARGET_HOME/.config/fastfetch"
mkdir -p "$FASTFETCH_DIR"
FASTFETCH_LOGO_SRC="${SCRIPT_DIR}/../configs/fastfetch/logo.txt"
FASTFETCH_CONFIG_SRC="${SCRIPT_DIR}/../configs/fastfetch/config.jsonc"

if [ -f "$FASTFETCH_LOGO_SRC" ]; then
    cp -f "$FASTFETCH_LOGO_SRC" "$FASTFETCH_DIR/"
    chown "$TARGET_USER:$TARGET_USER" "$FASTFETCH_DIR/logo.txt"
fi

if [ -f "$FASTFETCH_CONFIG_SRC" ]; then
    cp -f "$FASTFETCH_CONFIG_SRC" "$FASTFETCH_DIR/"
    chown "$TARGET_USER:$TARGET_USER" "$FASTFETCH_DIR/config.jsonc"
    success "Configuración de fastfetch copiada."
else
    error "No se encontró el archivo de configuración de fastfetch en $FASTFETCH_CONFIG_SRC"
    exit 1
fi

# ghostty
GHOSTTY_CONF_SRC="${SCRIPT_DIR}/../configs/config.ghostty"
GHOSTTY_DIR="$TARGET_HOME/.config/ghostty"
mkdir -p "$GHOSTTY_DIR"
if [ -f "$GHOSTTY_CONF_SRC" ]; then
    cp -f "$GHOSTTY_CONF_SRC" "$GHOSTTY_DIR/config"
    chown "$TARGET_USER:$TARGET_USER" "$GHOSTTY_DIR/config"
    success "Configuración de ghostty copiada."
else
    error "No se encontró el archivo de configuración de ghostty en $GHOSTTY_CONF_SRC"
    exit 1
fi

success "🎉 ¡Módulo de ZSH completado con éxito!"