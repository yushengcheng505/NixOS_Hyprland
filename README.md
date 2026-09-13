# NixOS Hyprland configuration

This repository contains the declarative NixOS, Hyprland, and Quickshell configuration for the Honor FMB-P laptop.

## Restore on a fresh NixOS installation

The commands below assume that the target machine uses the `nixos` hostname and an `x86_64-linux` system.

```bash
sudo git clone https://github.com/yushengcheng505/NixOS_Hyprland /etc/nixos
cd /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

The flake enables the modern Nix CLI and flakes, installs the declared system packages, and recreates the links for:

- `/home/klenko/.config/hypr`
- `/home/klenko/.config/quickshell/cartoon-shell`

If either destination already exists as a real directory, move it aside before rebuilding. The activation scripts intentionally refuse to overwrite existing files.

To validate a configuration without activating it:

```bash
sudo nixos-rebuild dry-build --flake /etc/nixos#nixos
```

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

The current `configuration.nix` expects the Discord and ChatGPT archives to be present in `/etc/nixos` when building. Obtain those files separately and verify their versions before running `nixos-rebuild`. Hermes Agent must likewise be installed and configured separately after the system restore.

Do not commit API keys, GitHub credentials, SSH keys, Wi-Fi profiles, Hermes authentication files, cookies, or other secrets to this public repository.
