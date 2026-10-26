{ pkgs, desktopApps, ... }:

let
  inherit (desktopApps)
    discord discordApp telegram telegramApp chatgpt chatgptSafe
    spotifyWayland chromeAuto chromeProxy chromeDirect
    chromeAutoDesktop chromeProxyDesktop chromeDirectDesktop orcaIde easycliproxyapi;
in
{
  environment.systemPackages = [
    discord
    discordApp
    telegram
    telegramApp
    pkgs.codex
    chatgpt
    chatgptSafe
    pkgs.zed-editor
    spotifyWayland
    pkgs.nodejs
    (pkgs.writeShellScriptBin "kimi" ''
      exec ${pkgs.nodejs}/bin/npx --yes @moonshot-ai/kimi-code@latest "$@"
    '')
    pkgs.google-chrome
    chromeAuto
    chromeProxy
    chromeDirect
    chromeAutoDesktop
    chromeProxyDesktop
    chromeDirectDesktop
    pkgs.python3
    pkgs.gh
    pkgs.btop
    pkgs.libreoffice-qt-stable
    pkgs.bluez
    orcaIde
    easycliproxyapi
  ];

  programs.firefox.enable = true;
  programs.nix-ld.enable = true;
}
