{ pkgs, discordArchive, chatgptArchive }:

let
  discordPackages = import ./discord.nix { inherit pkgs discordArchive; };
  chatgptPackages = import ./chatgpt.nix { inherit pkgs chatgptArchive; };
  spotifyWayland = pkgs.symlinkJoin {
    name = "spotify-wayland";
    paths = [ pkgs.spotify ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/spotify"
      makeWrapper "${pkgs.spotify}/bin/spotify" "$out/bin/spotify" \
        --add-flags "--enable-features=UseOzonePlatform" \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--proxy-server=http://127.0.0.1:2080"
    '';
  };

  telegramApp = pkgs.writeShellScriptBin "telegram-app" ''
    export HTTP_PROXY=http://127.0.0.1:2080
    export HTTPS_PROXY=http://127.0.0.1:2080
    export ALL_PROXY=http://127.0.0.1:2080
    exec ${pkgs.telegram-desktop}/bin/Telegram "$@"
  '';

  telegramDesktopItem = pkgs.makeDesktopItem {
    name = "org.telegram.desktop";
    desktopName = "Telegram";
    genericName = "Telegram Messenger";
    comment = "Fast and secure messaging";
    exec = "telegram-app -- %U";
    tryExec = "telegram-app";
    icon = "org.telegram.desktop";
    terminal = false;
    startupNotify = true;
    startupWMClass = "TelegramDesktop";
    categories = [ "Chat" "Network" "InstantMessaging" ];
    mimeTypes = [ "x-scheme-handler/tg" "x-scheme-handler/tonsite" ];
    keywords = [ "tg" "chat" "im" "messaging" "messenger" ];
    extraConfig.DBusActivatable = "false";
  };

  telegram = pkgs.symlinkJoin {
    name = "telegram-desktop-proxy-${pkgs.telegram-desktop.version}";
    paths = [ pkgs.telegram-desktop ];
    postBuild = ''
      rm "$out/share/applications/org.telegram.desktop.desktop"
      ln -s ${telegramDesktopItem}/share/applications/org.telegram.desktop.desktop \
        "$out/share/applications/org.telegram.desktop.desktop"
    '';
  };

  thronePac = pkgs.writeText "throne.pac" ''
    function FindProxyForURL(url, host) {
      if (
        isPlainHostName(host) ||
        host === "localhost" ||
        host === "::1" ||
        shExpMatch(host, "127.*") ||
        shExpMatch(host, "10.*") ||
        shExpMatch(host, "192.168.*") ||
        shExpMatch(host, "172.16.*") ||
        shExpMatch(host, "172.17.*") ||
        shExpMatch(host, "172.18.*") ||
        shExpMatch(host, "172.19.*") ||
        shExpMatch(host, "172.2?.*") ||
        shExpMatch(host, "172.3?.*") ||
        shExpMatch(host, "100.64.*") ||
        shExpMatch(host, "*.ts.net") ||
        shExpMatch(host, "*.local")
      ) {
        return "DIRECT";
      }
      return "PROXY 127.0.0.1:2080; DIRECT";
    }
  '';

  thronePacDir = pkgs.runCommand "throne-pac-dir" {} ''
    mkdir -p $out
    cp ${thronePac} $out/throne.pac
  '';

  chromeAuto = pkgs.writeShellScriptBin "google-chrome-auto" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --proxy-pac-url=http://127.0.0.1:18765/throne.pac "$@"
  '';

  chromeProxy = pkgs.writeShellScriptBin "google-chrome-proxy" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --proxy-server=http://127.0.0.1:2080 "$@"
  '';

  chromeDirect = pkgs.writeShellScriptBin "google-chrome-direct" ''
    exec ${pkgs.google-chrome}/bin/google-chrome-stable \
      --no-proxy-server "$@"
  '';

  chromeAutoDesktop = pkgs.makeDesktopItem {
    name = "google-chrome-throne";
    desktopName = "Google Chrome (Throne PAC)";
    comment = "Use Throne when available, otherwise connect directly";
    exec = "google-chrome-auto %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
  };

  chromeProxyDesktop = pkgs.makeDesktopItem {
    name = "google-chrome-throne-proxy";
    desktopName = "Google Chrome (Throne Proxy Only)";
    comment = "Always use the local Throne proxy";
    exec = "google-chrome-proxy %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
  };

  chromeDirectDesktop = pkgs.makeDesktopItem {
    name = "google-chrome-direct";
    desktopName = "Google Chrome (Direct)";
    comment = "Connect directly without a proxy";
    exec = "google-chrome-direct %U";
    icon = "google-chrome";
    categories = [ "Network" "WebBrowser" ];
  };
in
{
  inherit (discordPackages) discord discordApp;
  inherit (chatgptPackages) chatgpt chatgptSafe;
  inherit spotifyWayland telegram telegramApp thronePacDir;
  inherit chromeAuto chromeProxy chromeDirect chromeAutoDesktop chromeProxyDesktop chromeDirectDesktop;
  orcaIde = import ./orca.nix { inherit pkgs; };
  easycliproxyapi = pkgs.callPackage ./easycliproxyapi.nix { };
}
