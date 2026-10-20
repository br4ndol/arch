# arch-setup

Scripts para instalar y configurar mi Arch Linux tal como lo documento en
`ArchLinux2/` (mi wiki personal, fuera de git): kernel `linux-cachyos-bore` con UKI + EFISTUB,
repos CachyOS v3 y Chaotic-AUR, GNOME, Nvidia híbrida, etc.

Dos fases:

| Fase | Script | Dónde se ejecuta |
| --- | --- | --- |
| 1. Instalación | `install.sh` | En la ISO de Arch. Se relanza solo dentro de `arch-chroot /mnt`. |
| 2. Post-instalación | `post.sh` | En el sistema ya instalado, con `sudo`. |

Principios:

- **Idempotente:** se puede ejecutar las veces que haga falta. Cada paso comprueba antes de actuar y lo que ya está hecho se salta.
- **Sistema limpio:** solo instala lo listado en `config/packages/`. Al instalar desde AUR borra las dependencias de compilación (`--removemake`). Al terminar la instalación borra su copia temporal de `/root`, y `post.sh` acaba con una limpieza (huérfanos y cachés).
- **Simple de cambiar:** un archivo por tarea. La lógica va en `modules/` y los datos en `config/`.

## Estado

Las dos fases están completas y probadas desde cero en una VM de VirtualBox (UEFI, NVMe).

**Pendiente de comprobar en hardware real**, porque la VM no lo tiene:
- la rama Nvidia de `drivers`;
- `asusctl` y `rog-control-center`;
- el brillo del monitor externo con `ddcutil`.

**Opcional:** gaming (`ArchLinux2/gaming.md`). `post.sh` pregunta al principio si instalarlo.

## Qué hace cada módulo

### `install.sh` — etapa live (en la ISO)

| Módulo | Qué hace |
| --- | --- |
| `preflight` | Comprueba UEFI, internet, CPU x86-64-v3 y reloj NTP |
| `settings` | Hace las preguntas iniciales y las guarda en `config/settings.local.conf` |
| `repos` | Configura CachyOS v3 (antes de `[core]`), multilib, Chaotic-AUR y `[cachyos]`. Las llaves se verifican por huella, sin keyserver. Activa `Color` + `ILoveCandy` |
| `disk` | Formatea la ESP (FAT32) y la raíz (ext4) y las monta en `/mnt` y `/mnt/efi` |
| `pacstrap` | Instala el sistema base mínimo (`config/packages/base.list`) y genera `fstab` |

### `install.sh` — etapa chroot (en el sistema nuevo)

| Módulo | Qué hace |
| --- | --- |
| `system` | Zona horaria, locale, teclado y hostname |
| `users` | Crea el usuario en `wheel` con sudo, y pone la misma contraseña al usuario y a root |
| `repo` | Deja una copia del repo en `~/arch` (con tus respuestas, menos el hash de la contraseña) para ejecutar `post.sh` nada más arrancar |
| `network` | NetworkManager con iwd |
| `boot` | Cmdline, UKI principal y de respaldo con sus entradas EFI, y la copia `BOOTX64.EFI` |

### `post.sh` (en el sistema instalado)

| Módulo | Qué hace |
| --- | --- |
| `mirrors` | `rate-mirrors` y el script `mirror-update` |
| `auth` | `pwfeedback` y faillock (10 intentos, 5 min) |
| `maintenance` | `fstrim.timer` y un hook de pacman con `paccache`. No queda nada corriendo |
| `zram` | 8 GiB comprimidos con zstd y `zswap.enabled=0` |
| `aur` | `yay` desde chaotic-aur |
| `drivers` | Intel, o Intel + Nvidia, según `GPU`. Con `none` no hace nada |
| `audio` | PipeWire, EasyEffects (Flatpak) y los presets de JackHack96 (Perfect EQ, bass, Dolby Atmos, Laptop…) con sus `.irs` |
| `bluetooth` | BlueZ |
| `asus` | `asusctl`, `rog-control-center` y `power-profiles-daemon` |
| `plymouth` | Tema `bgrt` y `quiet splash …` en el cmdline |
| `zsh` | Starship, plugins y fzf-tab. Root también usa zsh, con su propia copia de la configuración |
| `desktop/gnome` | GNOME, GDM, `gnome-keyring`, `gnome-browser-connector`, `gnome-extensions-app`, apps Flatpak, y ajustes y atajos por defecto |
| `theme` | adw-gtk3 (oscuro por defecto), iconos MoreWaita (`-git`), cursor Bibata, y Qt con el tema `gtk3` |
| `nautilus` | Extras, carpetas XDG sin Plantillas ni Público, marcadores (Descargas, Imágenes, Documentos, "File System") y Samba |
| `apps` | Brave Origin, VSCodium y AppImages (`fuse2` + Gear Lever) |
| `gaming` | **Opcional.** Steam, gamescope, gamemode (con aviso), MangoHud, vkBasalt, Proton-CachyOS (SLR), Faugus Launcher y NTSYNC |
| `dotfiles` | Copia `config/files/home/` a tu HOME (Ghostty, Fastfetch) |
| `cleanup` | Al final: quita dependencias huérfanas y vacía la caché de pacman, la de yay y los runtimes Flatpak sin usar |

## Uso en la ISO

1. Arranca la ISO **en modo UEFI** y conéctate a internet (`iwctl` para wifi).
2. Crea las dos particiones con `cfdisk` (ver `ArchLinux2/Esquema.md`):
   - ESP de 1 GiB, tipo *EFI System*. Se montará en `/efi`.
   - El resto para `/`.

   No hace falta formatearlas: el script formatea las dos.
3. Descarga el repo y ejecuta (la ISO no trae `git`, por eso se instala primero):

   ```bash
   pacman -Sy git
   git clone https://github.com/br4ndol/arch
   cd arch && ./install.sh
   ```

   Sin instalar nada, con `curl`, que sí viene en la ISO:

   ```bash
   curl -L github.com/br4ndol/arch/archive/main.tar.gz | tar xz
   cd arch-main && ./install.sh
   ```

**Para no escribir a mano:** la ISO trae SSH. En el portátil, ejecuta `passwd` (contraseña temporal) e `ip -br a` (para ver su IP). Desde otro PC de la misma red conéctate con `ssh root@<IP>` y pega los comandos.

La primera vez te pregunta los datos de la instalación. Entre corchetes aparece el valor por defecto; con Enter lo aceptas.

```
? Partición para /efi (se formatea en FAT32)      -> nvme1n1p1
? Partición para / (se formatea en ext4)          -> nvme1n1p2
? Usuario [br4ndol]
? Hostname [arx-br4ndol]
? Zona horaria [America/Santo_Domingo]
? Locale [en_US.UTF-8]
? Keymap de la consola [us]
? ¿Qué drivers instalar?  1) nvidia-hybrid  2) intel  3) none
? Contraseña / Repite      (no se muestra; vale para tu usuario y para root)
```

De la contraseña solo se guarda su hash SHA-512 (el mismo formato de `/etc/shadow`), nunca el texto.

La opción de drivers por defecto se detecta: `none` en una máquina virtual, `nvidia-hybrid` si hay una Nvidia y si no `intel`. Así las pruebas en VM no instalan los drivers de Nvidia.

Las respuestas se guardan en `config/settings.local.conf`. En las siguientes ejecuciones solo te muestra el resumen y pregunta si lo usas.

Antes de formatear tienes que escribir `FORMATEAR`. Esa confirmación no se salta ni con `--yes`.

Al terminar, desmonta con `umount -R /mnt`, quita la ISO y reinicia. El repo queda copiado en `~/arch` de tu usuario, listo para la fase 2. El firmware arranca directamente el UKI (`/efi/EFI/Linux/arch-linux-cachyos-bore.efi`) desde la entrada EFI "Arch Linux (cachyos-bore)".

También se genera un **UKI de respaldo** (`arch-linux-cachyos-bore-fallback.efi`, con todos los módulos y sin `autodetect`) con su propia entrada, "Arch Linux (cachyos-bore fallback)". Elígela en el menú de arranque del firmware si un cambio en `MODULES` o en el cmdline rompe el principal.

Además hay una copia del UKI principal en la ruta de respaldo UEFI `\EFI\BOOT\BOOTX64.EFI`. El firmware la arranca si pierde la entrada (al resetear la BIOS, al actualizar el firmware o en VirtualBox, que las olvida). Un post hook de mkinitcpio (`/etc/initcpio/post/arch-setup-uki-fallback`) la actualiza cada vez que se regenera el UKI.

## Uso en el sistema instalado

Inicia sesión con tu usuario (en la TTY, todavía sin escritorio) y ejecuta:

```bash
cd ~/arch && sudo ./post.sh
```

`install.sh` dejó ahí la misma versión con la que instalaste, junto con tus respuestas (`settings.local.conf` sin el hash de la contraseña), así que `drivers` ya sabe qué GPU elegiste. Si la instalaste con `git clone`, la copia conserva `.git`: tras el módulo `zsh` (que instala `git`), `cd ~/arch && git pull` la pone al día.

Sin esa copia (por ejemplo, en un sistema instalado a mano): `curl -L github.com/br4ndol/arch/archive/main.tar.gz | tar xz && cd arch-main && sudo ./post.sh`.

- **Drivers de vídeo:** si no hay `settings.local.conf` (descarga nueva), el módulo `drivers` vuelve a preguntar (`nvidia-hybrid`, `intel` o `none`, detectado automáticamente). Para no tener que responder, pon `GPU=` en `config/settings.conf`.
- **Escritorio:** `DESKTOP` en `settings.conf` elige el módulo `desktop/<nombre>`.
- **Ajustes de GNOME:** se instalan como valores **por defecto** del sistema (dconf, en `/etc/dconf/db/local.d/`). No hace falta tener la sesión abierta y luego puedes cambiarlos desde Configuración. Si ya elegiste otro valor en tu sesión, el tuyo tiene prioridad. Para volver al del script: `gsettings reset <schema> <clave>`.
- **Energía:** con cargador no se suspende nunca. Con batería se suspende (y bloquea) a los 15 minutos sin uso.
- **Gaming:** al empezar, `post.sh` pregunta si instalarlo (por defecto no; con `--yes`, no). Para no responder, pon `GAMING=yes` o `GAMING=no` en `settings.conf`. `sudo ./post.sh --only gaming` lo instala directamente. Necesita los drivers de vídeo: con `GPU=none` se omite. Proton-CachyOS se instala desde el repo (variante SLR): Steam lo muestra en la lista de Proton y Faugus como "Proton-CachyOS (System)". Lo que sigue siendo manual: los argumentos de lanzamiento (`ENABLE_VKBASALT=1 prime-run gamemoderun mangohud %command%`; `prime-run` solo en modo híbrido) y el modo de compatibilidad de enfoque de los menús de Steam.
- **Atajos de brillo:** solo se crean si defines `MONITOR_SERIAL` (lo ves con `ddcutil detect`).
- **Tema claro/oscuro:** arranca en oscuro. El botón "Estilo oscuro" del panel cambia al momento las apps GTK4/libadwaita. Para que las GTK3, Flatpak y Qt cambien también (`adw-gtk3` ↔ `adw-gtk3-dark`), instala a mano desde extensions.gnome.org la extensión *Legacy (GTK3) Theme Scheme Auto Switcher* (el script no instala extensiones). Las apps Qt toman el tema al abrirse.
- **mirror-update:** `rate-mirrors` no se deja ejecutar como root, así que el script lo lanza como el usuario que llamó a `sudo` y solo escribe los mirrorlists como root.

Al terminar, reinicia: GDM arranca y entras a GNOME.

## Opciones

Valen igual para `install.sh` y `post.sh`:

| Opción | Qué hace |
| --- | --- |
| `-n`, `--dry-run` | Muestra lo que haría, sin cambiar nada. |
| `-y`, `--yes` | No pregunta y usa los valores por defecto. |
| `-v`, `--verbose` | Muestra mensajes de depuración. |
| `-l`, `--list` | Lista los módulos y sale. |
| `-o`, `--only a,b` | Ejecuta solo esos módulos. |
| `-s`, `--skip a,b` | Salta esos módulos. |
| `-k`, `--keep-going` | Si un módulo falla, sigue con el siguiente. |

Ejemplos:

```bash
./install.sh --list
./install.sh --dry-run
./install.sh --only repos,pacstrap     # repetir solo esos módulos
```

Si un módulo falla, el resumen final te dice el `--only` para repetir solo ese. Todo queda registrado en `/var/log/arch-setup.log`. El log de la etapa live se copia al sistema nuevo como `/var/log/arch-setup-live.log`.

## Configuración

- **`config/settings.conf`**: valores por defecto (usuario, hostname, kernel, GPU, escritorio, helper AUR `yay`…).
- **`config/settings.local.conf`**: tus respuestas en esta máquina. Se carga después de `settings.conf`, tiene prioridad y no se sube a git. Bórralo para que el script vuelva a preguntar.
- **`config/packages/*.list`**: listas de paquetes. Va un paquete por línea (o varios separados por espacios) y `#` marca comentarios. Con un prefijo eliges de dónde se instala:

  ```
  gnome-shell gdm                  # repos (oficiales, cachyos, chaotic-aur)
  aur:ghostty-nautilus             # AUR con yay
  flatpak:org.gnome.Calculator     # Flathub
  ```

- **`config/files/`**: plantillas de archivos que se copian al sistema. Pueden usar `{{VARIABLE}}`, que se sustituye por el valor de `settings.conf`.
- **`config/files/home/`**: refleja tu HOME. El módulo `dotfiles` copia cada archivo a la misma ruta dentro de `~`, a tu nombre. Por ejemplo, `config/files/home/.config/ghostty/config.ghostty` acaba en `~/.config/ghostty/config.ghostty`. Ahí están las configs de Ghostty y Fastfetch (con el logo); para añadir otra, solo déjala en esa carpeta.

## Estructura

```
install.sh                 # orquestador fase 1: lista LIVE_MODULES y CHROOT_MODULES
post.sh                    # orquestador fase 2: lista POST_MODULES
utils/                     # funciones compartidas (ver abajo)
config/                    # settings, listas de paquetes y plantillas
modules/install/live/      # etapa live (ISO)
modules/install/chroot/    # etapa chroot (sistema nuevo)
modules/post/              # post-instalación
modules/post/desktop/      # un archivo por escritorio (gnome.sh…)
```

## Añadir o cambiar un módulo

1. Crea `modules/<fase>/<nombre>.sh`:

   ```bash
   #!/usr/bin/env bash
   # desc: Autenticación (pwfeedback, faillock)

   module_run() {
     log_step "sudo y faillock"
     write_file /etc/sudoers.d/pwfeedback 440 <<<'Defaults pwfeedback'
     set_kv /etc/security/faillock.conf deny 10
     set_kv /etc/security/faillock.conf unlock_time 300
   }
   ```

2. Añade `<nombre>` al array correspondiente de `install.sh` o `post.sh`, en el orden en que deba ejecutarse.

Cada módulo corre en un proceso aparte, con `set -e`: si un comando falla, el módulo se detiene ahí. Tiene a mano todas las funciones de `utils/` y las variables de la configuración.

Para que el módulo siga siendo idempotente, usa las funciones de `utils/` y no comandos sueltos. Por ejemplo, `pkg_install` en vez de `pacman -S` y `set_kv` en vez de `sed -i`.

## Funciones de `utils/`

| Archivo | Funciones |
| --- | --- |
| `log.sh` | `log_info` `log_ok` `log_warn` `log_error` `log_step` `log_section` `die` |
| `confirm.sh` | `confirm` `confirm_dangerous` `ask` (con validador opcional) `ask_secret` `choose` |
| `execute.sh` | `run` (respeta dry-run) `run_quiet` `retry` `run_as_user` `chroot_run` |
| `checks.sh` | `is_root` `is_uefi` `has_internet` `in_chroot` `in_live_iso` `is_mounted` `cmd_exists` `detect_gpu` `require_*` |
| `packages.sh` | `pkg_install` `pkg_remove` `aur_install` `flatpak_install` `install_list` |
| `files.sh` | `set_kv` `ensure_line` `ensure_line_after` `ensure_uncommented` `comment_line` `ensure_ini_section` `install_file` `write_file` `render_template` |
| `services.sh` | `service_enable [--now]` `service_disable` `service_enable_global` `service_enable_user` |
| `users.sh` | `user_add_group` `group_ensure` `user_home` `user_in_group` `user_mkdir` `user_install_file` `user_write_file` `user_ensure_line` (archivos del usuario con el dueño correcto) |
| `boot.sh` | `cmdline_add` `mkinitcpio_add` `uki_rebuild` |

Las funciones de `files.sh` hacen un backup (`archivo.bak-<fecha>`) antes del primer cambio de cada ejecución. Después dejan `FILE_CHANGED=1` si el archivo cambió y `0` si no; así puedes, por ejemplo, regenerar el UKI solo cuando haga falta.

## Notas

- **Avisos "Possibly missing firmware" al generar el UKI de respaldo:** son normales. El de respaldo incluye todos los drivers del kernel (AMD, servidores…), y solo está instalado `linux-firmware-intel`. Instalar el firmware completo para silenciarlos añadiría cientos de MB que nunca se usan.
- **Paquetes Qt quitados de `theme.list`:** `qgnomeplatform-qt5/qt6` y `qadwaitadecorations-qt5`. No compilan o chocan con el `qt5-wayland` de CachyOS. Qt usa el tema `gtk3`, que viene de serie.
- **Módulos de Nvidia en el initramfs** (`drivers`): se cargan pronto a propósito, porque el monitor externo va conectado a la Nvidia y el portátil tiene modo solo-dGPU (MUX).
- Si editas desde Windows, `.gitattributes` fuerza finales de línea LF en los scripts. Con CRLF fallarían en Linux.
- Para validar desde Windows con el WSL de Arch: `shellcheck -x` sobre todos los `.sh`.

## Probar en VirtualBox

Se usa la VM `arch-setup-test`, con EFI, disco NVMe y `nvme0n1` como en el portátil. Tiene estos snapshots para volver a cualquier punto:

| Snapshot | Estado |
| --- | --- |
| `disco-vacio` | Disco vacío con la ISO puesta. Sirve para probar todo desde cero |
| `completa-v2` | `install.sh` + `post.sh` completos con la versión actual |

Para pasar el script a la VM:
- Si los cambios ya están en GitHub, con el `curl … | tar xz` de arriba.
- Si no, sirviendo un `.tar.gz` desde el PC. La VM llega al PC en `http://10.0.2.2:<puerto>/` (red NAT de VirtualBox).
