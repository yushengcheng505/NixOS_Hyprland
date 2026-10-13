# NixOS Hyprland configuration

This repository contains the declarative NixOS, Hyprland, and Quickshell configuration for the Honor FMB-P laptop.

## Restore on a fresh NixOS installation

The commands below assume that the target machine uses the `nixos` hostname, an `x86_64-linux` system, and a fresh NixOS install where the user account `klenko` and its home directory `/home/klenko` have already been created (by the installer or manually).

Clone the repository as that user into a mutable checkout under the home directory — not into `/etc/nixos`. The checkout must stay user-writable because Quickshell's theme service (matugen) writes generated theme files into `dotfiles/` at runtime, and the desktop configuration is symlinked to this tree.

```bash
git clone https://github.com/yushengcheng505/NixOS_Hyprland /home/klenko/nixos
cd /home/klenko/nixos
```

Before building, place the two local installer archives in the repository root. They are not committed to the repository and there is no download URL for them — obtain the exact files you previously used and verify the versions match what `configuration.nix` declares:

- `discord-full.distro` — Discord 1.0.157
- `chatgpt_amd64.deb` — ChatGPT 26.901.51231

Then evaluate and build the configuration:

```bash
nix flake check --no-update-lock-file path:/home/klenko/nixos
nixos-rebuild build --flake path:/home/klenko/nixos#nixos
```

If the build succeeds, apply it later as root:

```bash
sudo nixos-rebuild switch --flake path:/home/klenko/nixos#nixos
```

On a fresh restore, finish by setting the user password:

```bash
sudo passwd klenko
```

### Why `path:` and what gets copied

The flake is referenced as `path:/home/klenko/nixos`, not `git+file:...` or `/home/klenko/nixos`. A `path:` flake includes the entire directory tree — ignored files such as `discord-full.distro` and `chatgpt_amd64.deb`, and untracked files — when it is copied into the Nix store. That is required here because `configuration.nix` sources those ignored archives with `./discord-full.distro` and `./chatgpt_amd64.deb`.

The consequence: anything sitting in the checkout is copied into the world-readable Nix store. Do not keep secrets, backups, or scratch files inside the repository tree. `.gitignore` excludes new `*.before-*`, `*.deb`, and `*.distro` files from normal Git additions, but does not remove files already tracked or staged. Check the Git index before committing. Git-ignore status does not keep files out of the store copy — backups should live outside the checkout.

`nixos-rebuild build` leaves a `result` symlink in the checkout as usual. For ad-hoc `nix build` invocations, pass `--no-link` so you don't accumulate `result` links that would themselves be copied on the next build.

## Desktop configuration links

Activation scripts symlink the desktop configuration into the user home:

- `/home/klenko/.config/hypr` → `/home/klenko/nixos/dotfiles/hypr`
- `/home/klenko/.config/quickshell/cartoon-shell` → `/home/klenko/nixos/dotfiles/quickshell/cartoon-shell`

The activation script is deliberately strict:

- A symlink already pointing at the new source is left alone.
- A symlink pointing at the old `/etc/nixos/dotfiles/...` location is migrated to the new source.
- A symlink pointing anywhere else, or any real file or directory at the target, causes activation to fail rather than overwrite it — move the path aside before switching.

Because the targets are symlinks into the checkout, theme changes written by Quickshell/matugen land in `dotfiles/` directly and survive reboots; they appear as local modifications in `git status`.

## Direct Hyprland session

Select **Hyprland** in SDDM. This configuration does not use UWSM. The session launcher retains upstream `start-hyprland` and its watchdog, and stops `hyprland-session.target` when the launcher exits. A runtime lock prevents a second managed direct session for the same user. Cleanup cannot be guaranteed if the launcher itself is killed with SIGKILL.

On compositor readiness, `hyprland-session-ready` stops stale session services, imports the display/session environment into the user manager and D-Bus activation environment, resets only failed session services, then starts the target. Its dependency starts `graphical-session.target`; neither target needs to be active before readiness runs. Quickshell, hypridle, EasyCLIProxyAPI and the standard portal services are attached to that target. The headless Throne PAC server remains independent of the graphical session. Readiness diagnostics are recorded in `journalctl -b -t hyprland-session-ready`.

For changes to session management, prefer `sudo nixos-rebuild boot --flake path:/home/klenko/nixos#nixos`, then save your work and reboot. This avoids replacing portal and GUI services in the running session. Later, also test logout and login without rebooting. Do not manually run the readiness helper from a terminal outside the intended compositor environment. Check `systemctl --user --failed`, `qs list --all`, and actual Discord screen sharing after the new login. A successful build alone does not verify logout/login cleanup or screen capture.

## What is included

- NixOS system and hardware configuration;
- Hyprland Lua configuration;
- Quickshell Cartoon Shell configuration and assets;
- package and service declarations, including NetworkManager and LibreOffice.

## External dependencies not stored here

This is not a byte-for-byte system image. The following components are intentionally excluded from the repository:

- Discord runtime archive (`discord-full.distro`);
- ChatGPT package (`chatgpt_amd64.deb`);
- Hermes Agent package, user profile, service state, and authentication data;
- user data, application profiles, and secrets.

The current `configuration.nix` expects the Discord and ChatGPT archives to be present in `/home/klenko/nixos` when building. Obtain those files separately and verify their versions before running `nixos-rebuild`. Hermes Agent must likewise be installed and configured separately after the system restore.

Do not commit API keys, GitHub credentials, SSH keys, Wi-Fi profiles, Hermes authentication files, cookies, or other secrets to this public repository — and do not leave them inside the checkout either, since the `path:` flake copies the whole tree into the Nix store.
