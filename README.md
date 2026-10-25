# NixOS Hyprland configuration

This repository contains the declarative NixOS, Hyprland, and Quickshell configuration for the Honor FMB-P laptop.

## Restore on a fresh NixOS installation

The commands below assume that the target machine uses the `nixos` hostname, an `x86_64-linux` system, and a fresh NixOS install where the user account `klenko` and its home directory `/home/klenko` have already been created (by the installer or manually).

Clone the repository as that user into a checkout under the home directory — not into `/etc/nixos`. The desktop configuration is symlinked to this tree; keep it user-writable for source edits. Generated themes and application state live outside the checkout.

```bash
git clone https://github.com/yushengcheng505/NixOS_Hyprland /home/klenko/nixos
cd /home/klenko/nixos
```

Before building, place the two local installer archives in the repository root. They are not committed to the repository and there is no download URL for them. The flake loads them as separate, hash-locked file inputs at these exact paths:

- `/home/klenko/nixos/discord-full.distro` — Discord 1.0.157; SHA-256 `7c3ab8a0cde6f707aea44b7fce055acafc62d2946058a3a77d48c3329229a41d`
- `/home/klenko/nixos/chatgpt_amd64.deb` — ChatGPT 26.901.51231; SHA-256 `62580188d87c3d3a9369dab7c73b42a8a32518d4df8a2d5bae6466ddeac5c05e`

Verify the archive hashes, then evaluate and build the configuration without creating a `result` link:

```bash
sha256sum discord-full.distro chatgpt_amd64.deb
nix flake check --no-update-lock-file git+file:///home/klenko/nixos
nix build --no-link --print-out-paths --no-update-lock-file git+file:///home/klenko/nixos#nixosConfigurations.nixos.config.system.build.toplevel
```

If the build succeeds, apply it later as root:

```bash
sudo nixos-rebuild switch --flake git+file:///home/klenko/nixos#nixos
```

On a fresh restore, finish by setting the user password:

```bash
sudo passwd klenko
```

### Git source snapshots and local archives

Use `git+file:///home/klenko/nixos`, not `path:/home/klenko/nixos`. The Git flake snapshots tracked files, including their local modifications, but excludes `.git`, untracked backups, ignored installer archives and `result` links. New source files must be added to the Git index before Nix can see them. No commit is needed to build modified tracked files. Review the index before any commit; never add credentials or installer archives.

The two archives are fetched separately through `file+file:` inputs declared with `flake = false`. Their NAR hashes in `flake.lock` pin their contents; `builtins.path` restores their original filenames for unchanged package derivations. Moving the checkout requires updating both local input URLs. Replacing an archive requires an intentional update of that input's lock and package version, not a blanket nixpkgs update.

A `path:` flake still copies the entire directory, including `.git` and ignored files. Do not use it for routine builds. Keep secrets and future backups outside the checkout; files copied into the Nix store are world-readable. Existing ignored backups are not imported by the Git workflow.

`nixos-rebuild build` creates a `result` link that keeps its output alive during garbage collection. Prefer the `nix build --no-link` command above for checks; keep deliberate build links only when you need to retain their results.

## Desktop configuration links

Activation scripts symlink the desktop configuration into the user home:

- `/home/klenko/.config/hypr` → `/home/klenko/nixos/dotfiles/hypr`
- `/home/klenko/.config/quickshell/cartoon-shell` → `/home/klenko/nixos/dotfiles/quickshell/cartoon-shell`

The activation script is deliberately strict:

- A symlink already pointing at the new source is left alone.
- A symlink pointing at the old `/etc/nixos/dotfiles/...` location is migrated to the new source.
- A symlink pointing anywhere else, or any real file or directory at the target, causes activation to fail rather than overwrite it — move the path aside before switching.

Generated matugen themes are written atomically to `${XDG_STATE_HOME:-$HOME/.local/state}/cartoon-shell/matugen.json`, not into the checkout. The tracked `assets/themes/matugen.json` is a read-only fallback for missing or invalid generated state. Existing palette/settings files remain in the user's configuration directory. Theme generation no longer modifies tracked files; existing source changes still need a deliberate Git commit before the working tree becomes clean.

## Direct Hyprland session

Select **Hyprland** in SDDM. This configuration does not use UWSM. The session launcher retains upstream `start-hyprland` and its watchdog, and stops `hyprland-session.target` when the launcher exits. A runtime lock prevents a second managed direct session for the same user. Cleanup cannot be guaranteed if the launcher itself is killed with SIGKILL.

On compositor readiness, `hyprland-session-ready` stops stale session services, imports the display/session environment into the user manager and D-Bus activation environment, resets only failed session services, then starts the target. Its dependency starts `graphical-session.target`; neither target needs to be active before readiness runs. Quickshell, hypridle, EasyCLIProxyAPI and the standard portal services are attached to that target. The headless Throne PAC server remains independent of the graphical session and runs only for `klenko`, so the SDDM user manager cannot start a competing listener on port 18765. Readiness diagnostics are recorded in `journalctl -b -t hyprland-session-ready`.

Applications started from the launcher and links opened from the dashboard use `app2unit -t service -C`, so they run in separate user services and survive a Quickshell restart. They still stop with the graphical session. Applications started before this change may remain in Quickshell's cgroup: do not restart the shell while they contain unsaved work. Shell helper processes intentionally remain attached to `quickshell.service`.

For changes to session management, prefer `sudo nixos-rebuild boot --flake git+file:///home/klenko/nixos#nixos`, then save your work and reboot. This avoids replacing portal and GUI services in the running session. Later, also test logout and login without rebooting. Do not manually run the readiness helper from a terminal outside the intended compositor environment. Check `systemctl --user --failed`, `qs list --all`, and actual Discord screen sharing after the new login. A successful build alone does not verify logout/login cleanup or screen capture.

## Maintenance

Nix garbage collection runs weekly on Sunday after 15:17, with up to 30 minutes of randomized delay. It deletes only unreachable store paths: system and user profile generations are not expired automatically. Store hard-link optimization runs separately after 16:17 with the same delay range. Both timers are persistent, so a missed run can execute after the laptop next starts. Activate the rebuilt NixOS configuration before expecting these timers to exist.

For manual collection without removing rollback generations, use `nix store gc`. Do not delete files from `/nix/store` manually. Review old profile generations and intentional build-result links separately before removing their roots.

The `Super+L` action and the 15-minute idle timeout intentionally turn off the screen without locking the session.

## Application launchers

NixOS provides `discord-app`, `telegram-app` and `chatgpt-safe` in the system profile. Discord and Telegram inherit the local HTTP/HTTPS/ALL proxy at `127.0.0.1:2080`; Discord also keeps its native Wayland flags. ChatGPT's safe launcher keeps software rendering, native Wayland, fractional scaling and the local proxy. Each wrapper points to its own generation's application package, not a mutable `/run/current-system` target.

The desktop IDs remain `discord.desktop`, `org.telegram.desktop.desktop` and `chatgpt.desktop`. Telegram's desktop entry disables D-Bus activation so opening it cannot silently bypass the proxy wrapper. Existing MIME defaults are not changed by installing these entries.

When migrating an existing user profile, first install the new generation with `sudo nixos-rebuild boot --flake git+file:///home/klenko/nixos#nixos`, save your work and reboot. Changing the system package profile also changes D-Bus and Quickshell dependencies; using `boot` avoids replacing them underneath the running session. Verify that `/run/current-system/sw/bin/{discord-app,telegram-app,chatgpt-safe}` exist and that the three system desktop entries reference them. Then compare and archive the old matching files from `~/.local/bin` and `~/.local/share/applications`: user desktop entries override system entries, and user binaries can shadow system wrappers. Do not remove them before activation, do not overwrite later user changes, and preserve backups outside this checkout. Running applications do not need to be restarted for this migration; future launches use the new entries after the application menu refreshes.

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

Do not commit API keys, GitHub credentials, SSH keys, Wi-Fi profiles, Hermes authentication files, cookies, or other secrets to this public repository. Keep them outside the checkout: tracked files enter the world-readable Nix store, and accidentally using a `path:` reference also imports ignored and untracked files.
