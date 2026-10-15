# AGENTS.md

Guidance for AI coding agents working in this repository.

## Repository layout

The repo root is the installer itself ("arch-setup", a modular Bash installer that automates the user's wiki): `install.sh`, `post.sh`, `utils/`, `modules/`, `config/`. `README.md` (Spanish, user-facing) lists what every module does. The project name `arch-setup` still appears in system paths it creates (`/var/log/arch-setup.log`, `/etc/dconf/db/local.d/00-arch-setup`, `/etc/initcpio/post/arch-setup-uki-fallback`…); keep those names, since renaming would orphan files on installed systems.

- `ArchLinux2/` — the user's personal Arch Linux wiki (Spanish Markdown, Obsidian-style `[[links]]`) plus their original dotfiles in `ArchLinux2/config/`. It is the **source of truth** for what gets installed and configured. **Read it; never modify it.** It exists only locally: it is not tracked in git (nor are `.agents/`, `.claude/`, `skills-lock.json`).

The user writes in Spanish: reply, and write comments, log messages and docs, in Spanish.

## Development environment

Development happens on Windows; the scripts run on Arch Linux. Validation uses a WSL distro named `archlinux` (runs as root, bash 5.3, `shellcheck` installed; `cmp`/`diff` are **not** installed). Real tests use VirtualBox.

```powershell
# Lint everything (the only automated check; there is no test suite)
wsl -d archlinux -- bash -O globstar -c 'cd /mnt/c/Users/br4ndol/Documents/Proyectos/arch && shellcheck -x -S style *.sh utils/*.sh modules/**/*.sh config/files/mirror-update'
```

- PowerShell mangles nested quotes and `$` in `wsl -- bash -c '...'`. For anything non-trivial, write a script file and run `wsl -d archlinux -- bash <path>`.
- Unit-style checks are ad-hoc scripts that `source utils/common.sh` and exercise helpers on temp files (run each helper twice to prove idempotency). Use `DRY_RUN=1` to run a module without changes. Run against a copy in `/tmp` when the `settings` module is involved (it writes `config/settings.local.conf`).
- `--dry-run` still runs read-only checks (keyring lookups, mirror listing, lsblk). WSL is not UEFI and has no partitions, so `preflight`, `disk` and `boot` fail there by design.
- Check where a package lives before adding it: `pacman -Si` (official repos; WSL has no multilib), the chaotic-aur/cachyos `.db` files via `curl` + `bsdtar -tf`, and the AUR RPC (`https://aur.archlinux.org/rpc/v5/info?arg[]=<pkg>`). Prefer repo/chaotic-aur packages; `aur:` entries trigger a local build (and `base-devel`).
- Keep files LF (`.gitattributes` enforces it); CRLF breaks the scripts on Linux.

### VirtualBox test VM

- VM `arch-setup-test`: EFI, NVMe disk (`/dev/nvme0n1`, like the laptop), NAT with SSH forward `127.0.0.1:2222 → 22` and `localhostReachable=1`.
- Snapshots: `disco-vacio` (empty disk + ISO, full reinstall test) and `completa-v2` (current full install). Older ones (`fase1-ok`, `fase2-ok`, `fase2-completa`) predate later changes.
- `VBoxManage` is at `C:\Program Files\Oracle\VirtualBox\VBoxManage.exe`. Useful: `controlvm <vm> screenshotpng <file>` to see the screen (then read the PNG), `storageattach … --medium emptydrive|<iso>` to eject/insert the ISO, `snapshot … take|restore`.
- Getting the code into the VM: the ISO has SSH (`scp -P 2222`, after `passwd` in the VM); the installed system has neither `scp` nor `git`, so it downloads a tarball with `curl` — from GitHub once pushed, or from a host server at `http://10.0.2.2:<port>/` (the host has no Python; a tiny PowerShell `TcpListener` server works). Build the tarball from the repo root with only the installer: `tar -czf <out> --exclude config/settings.local.conf install.sh post.sh utils modules config` (never include `ArchLinux2/`, `.agents/`, `.claude/`). Run scripts with `bash script.sh` (tarballs built on Windows lose the exec bit).
- The user runs the interactive steps in the VM and pastes the output; changes are committed and pushed only when the user asks, after a VM test passes.

## Architecture

**Orchestrators** (`install.sh`, `post.sh`) only declare ordered module arrays (`LIVE_MODULES`, `CHROOT_MODULES`, and `post_modules()`, a function because `desktop/$DESKTOP` depends on config), parse the common flags (`utils/modules.sh`: `-n -y -v -l -o -s -k`) and call `run_modules`. Module order lives only there.

**Two-stage install:** `install.sh` runs the `live` stage on the ISO (`modules/install/live/`), then copies the repo into `/mnt/root/arch-setup`, re-executes itself via `arch-chroot /mnt … --stage chroot` with the same flags (`modules/install/chroot/`), and deletes the copy. Chroot modules run natively, so don't wrap commands in `arch-chroot`. `config/settings.local.conf` therefore does **not** survive into the installed system: `post.sh` runs from a fresh download with only `settings.conf` defaults, which is why `drivers` re-asks `GPU` (via `detect_gpu`) when it is empty.

**Module contract:** `modules/<phase>/<name>.sh` defines `module_run()` and a `# desc:` header line (shown by `--list`). `run_modules` executes each module in a **separate `bash` process** that sources `utils/common.sh`, calls `load_config`, then the module. This is deliberate: `set -e` is silently disabled inside `if`/`||` contexts and subshells inherit that, so in-process execution would not stop on errors. Consequences:
- Modules cannot pass variables back; persist data in `config/settings.local.conf` (the `settings` module does this). Every module reloads config.
- Global flags (`DRY_RUN`, `ASSUME_YES`, `VERBOSE`, `LOG_FILE`, `RUN_TS`) reach children via `export`.
- Prefer `if …; then …; fi` over `[[ … ]] && cmd` inside loops and at the end of functions.

**Config:** `config/settings.conf` (versioned defaults) is sourced, then `config/settings.local.conf` (gitignored, per machine), both with `set -a`. Avoid variable names bash already uses (hence `SYS_HOSTNAME`/`SYS_USER`). Data lives in `config/`: package lists `config/packages/*.list` (with `aur:` and `flatpak:` prefixes, handled by `install_list`), templates in `config/files/` (`{{VAR}}` via `render_template`; destination `-` prints to stdout), and `config/files/home/`, which mirrors `~` and is copied by the `dotfiles` module.

**Idempotency is check-based, not marker-based.** Every state change goes through a `utils/` helper:
- `run`/`retry`/`run_quiet` (`execute.sh`) are the only way to run mutating commands; that is what makes `--dry-run` work. Read-only checks run directly.
- `files.sh` helpers build a candidate in `$RUN_TMPDIR`, compare it with `same_content` (sha256; **never `cmp`/`diff`, diffutils is not in `base`**), back up once per run (`file.bak-$RUN_TS`, shared across module processes) and set `FILE_CHANGED=0|1`. Modules use it to decide e.g. `uki_rebuild` or `dconf update`.
- `boot.sh`: `cmdline_add` (replaces same-key params in place, so order is stable across modules), `mkinitcpio_add VAR item [after…]`, `uki_rebuild`.
- Files in the user's HOME must use the `user_*` helpers (`users.sh`) so they are owned by the user, never root (a root-owned `~/.config` breaks apps). `runuser` keeps root's `HOME`; pass `env HOME=…` when running user tools.
- `pkg_install`/`aur_install`/`flatpak_install` skip installed items. AUR helper is `yay`, run as `SYS_USER` via `runuser` with a temporary NOPASSWD sudoers file removed on exit, and `--removemake`.
- Avoid `cmd | grep -q` under `pipefail` (SIGPIPE false negatives); capture output into a variable first.

**User interaction** (`confirm.sh`): `ASSUME_YES` or no TTY fall back to defaults; `confirm_dangerous` (before formatting) always requires typing the word and ignores `--yes`. All logging goes to stderr so functions can return values on stdout.

**GNOME settings** are system-wide dconf defaults (`/etc/dconf/profile/user` + `/etc/dconf/db/local.d/*`, then `dconf update`), not `gsettings`: they work from a TTY/chroot without a D-Bus session. Keybindings are generated from `config/files/gnome/keybindings.list` (`name | binding | command`; lines using `{{MONITOR_SERIAL}}` are skipped when it is empty). GVariant types matter in keyfiles (e.g. `idle-delay=uint32 0`).

## Boot

EFISTUB + UKI built by mkinitcpio from `config/files/mkinitcpio.preset` (`default` and `fallback` with `-S autodetect`, each with its own efibootmgr entry; the fallback entry is created first so the main one ends up first in BootOrder). The main UKI is also copied to the UEFI fallback path `\EFI\BOOT\BOOTX64.EFI` by a mkinitcpio post hook (`/etc/initcpio/post/`, from `config/files/uki-fallback.hook`). VirtualBox's firmware drops efibootmgr entries, so never rely on the NVRAM entry alone. The ESP is always formatted by the script, so writing the fallback path is safe. Don't `chmod`/`install -m` on the ESP (FAT32): use `cp`. "Possibly missing firmware" warnings when building the fallback UKI are expected and harmless.

Repo keys (CachyOS, Chaotic-AUR) are extracted from the `*-keyring` packages downloaded over HTTPS and accepted only if the full fingerprint matches (`repos.sh`). Never go back to `pacman-key --recv-keys`: `keyserver.ubuntu.com` fails often.

## User preferences that constrain changes

- Simple and easy to modify: one task per module, data in `config/`, no extra abstraction layers.
- Clean system: install only what the lists/wiki specify; leave no helper files or extra packages behind. Base firmware is `linux-firmware-intel` only (covers the Intel AX211 Wi-Fi/BT and the iGPU).
- Minimal resident services: prefer timers, pacman hooks and socket activation (e.g. `fstrim.timer`, a `paccache` pacman hook, `gnome-keyring-daemon.socket`) over always-running daemons.
- GPU drivers are opt-in via `GPU` (`nvidia-hybrid | intel | none`), auto-detected (`none` in a VM). Every Nvidia-specific step must be gated on it: installing Nvidia in a VirtualBox VM broke the user's previous script. Nvidia modules stay in mkinitcpio `MODULES` on purpose (external monitor wired to the dGPU, MUX dGPU-only mode). No `nvidia-hibernate` (no hibernation, no disk swap).
- ASUS tooling is installed even in a VM (harmless). Gaming (`ArchLinux2/gaming.md`) is intentionally NOT automated.
- One password for the user and root, asked in `settings`; only its SHA-512 crypt hash (`PASSWORD_HASH`, applied with `chpasswd -e`) is persisted, never plaintext.
- Partitions are created manually with cfdisk; the script asks which is the ESP (`/efi`, FAT32) and which is root (`/`, ext4) and always formats both. ext4, no btrfs.
- Deliberate choices; don't "fix" them: `morewaita-icon-theme-git` (git version on purpose), zram with zstd plus `zswap.enabled=0`, Qt via the built-in `gtk3` platform theme (no qt5ct/qt6ct; `qgnomeplatform*` and `qadwaitadecorations-qt5` were removed because they don't build or conflict with CachyOS `qt5-wayland`), root uses zsh with its own config copy, and with GNOME on battery the laptop suspends after 15 min (never on AC).
- When the user changes a dotfile in `ArchLinux2/config/`, copy it byte-for-byte into `config/files/home/` (Nerd Font glyphs; verify with sha256).
