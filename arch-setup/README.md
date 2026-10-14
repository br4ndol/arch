# arch-setup

Scripts para instalar y configurar mi Arch Linux tal como lo documento en
[`ArchLinux2/`](../ArchLinux2/ArchLinux2.md): kernel `linux-cachyos-bore` con UKI + EFISTUB,
repos CachyOS v3 y Chaotic-AUR, GNOME, Nvidia híbrida, etc.

Dos fases:

| Fase | Script | Dónde se ejecuta |
| --- | --- | --- |
| 1. Instalación | `install.sh` | En la ISO de Arch. Se relanza solo dentro de `arch-chroot /mnt`. |
| 2. Post-instalación | `post.sh` | En el sistema ya instalado, con `sudo`. |

Principios:

- **Idempotente:** se puede ejecutar las veces que haga falta. Cada paso comprueba antes de actuar y lo que ya está hecho se salta.
- **Sistema limpio:** solo instala lo listado en `config/packages/`. Al instalar desde AUR borra las dependencias de compilación (`--removemake`). Al terminar la instalación borra su propia copia del sistema nuevo.
- **Simple de cambiar:** un archivo por tarea. La lógica va en `modules/` y los datos en `config/`.

## Estado

| Etapa | Módulos | Estado |
| --- | --- | --- |
| install · live | `preflight` `settings` `repos` `disk` `pacstrap` | Probado en VM |
| install · chroot | `system` `users` `network` `boot` | Probado en VM |
| post | — | Pendiente |

## Uso en la ISO

1. Arranca la ISO **en modo UEFI** y conéctate a internet (`iwctl` para wifi).
2. Crea las dos particiones con `cfdisk` (ver [Esquema](../ArchLinux2/Esquema.md)):
   - ESP de 1 GiB, tipo *EFI System*. Se montará en `/efi`.
   - El resto para `/`.

   No hace falta formatearlas: el script formatea las dos.
3. Descarga el repo y ejecuta:

   ```bash
   curl -L https://github.com/br4ndol/arch/archive/main.tar.gz | tar xz
   cd arch-main/arch-setup
   ./install.sh
   ```

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

Al terminar, desmonta con `umount -R /mnt`, quita la ISO y reinicia. El firmware arranca directamente el UKI (`/efi/EFI/Linux/arch-linux-cachyos-bore.efi`) desde la entrada EFI "Arch Linux (cachyos-bore)".

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
| `checks.sh` | `is_root` `is_uefi` `has_internet` `in_chroot` `in_live_iso` `is_mounted` `cmd_exists` `require_*` |
| `packages.sh` | `pkg_install` `pkg_remove` `aur_install` `flatpak_install` `install_list` |
| `files.sh` | `set_kv` `ensure_line` `ensure_uncommented` `comment_line` `ensure_ini_section` `install_file` `write_file` `render_template` |
| `services.sh` | `service_enable [--now]` `service_disable` `service_enable_global` `service_enable_user` |
| `users.sh` | `user_add_group` `group_ensure` `user_home` `user_in_group` |

Las funciones de `files.sh` hacen un backup (`archivo.bak-<fecha>`) antes del primer cambio de cada ejecución. Después dejan `FILE_CHANGED=1` si el archivo cambió y `0` si no; así puedes, por ejemplo, regenerar el UKI solo cuando haga falta.

## Notas

- Si editas desde Windows, `.gitattributes` fuerza finales de línea LF en los scripts. Con CRLF fallarían en Linux.
- Para validar desde Windows con el WSL de Arch: `shellcheck -x` sobre todos los `.sh`.
