{ pkgs, discordArchive }:

let
  discordUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "discord-unwrapped";
    version = "1.0.157";
    src = discordArchive;
    nativeBuildInputs = [ pkgs.brotli pkgs.gnutar ];
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/opt/Discord
      brotli -d < $src | tar xf - --strip-components=1 -C $out/opt/Discord
      chmod +x $out/opt/Discord/Discord
      sed -i "s|\"version\": \"1.0.157\"|\"version\": \"1.0.157\", \"disableUpdater\": true|" $out/opt/Discord/resources/build_info.json
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp $out/opt/Discord/discord.png $out/share/icons/hicolor/256x256/apps/discord.png
    '';
  };

  discordDesktopItem = pkgs.makeDesktopItem {
    name = "discord";
    desktopName = "Discord";
    genericName = "Internet Messenger";
    comment = "All-in-one voice and text chat";
    exec = "discord-app -- %U";
    tryExec = "discord-app";
    icon = "discord";
    terminal = false;
    startupNotify = true;
    startupWMClass = "discord";
    categories = [ "Network" "InstantMessaging" ];
    keywords = [ "chat" "voice" "gaming" ];
    mimeTypes = [ "x-scheme-handler/discord" ];
  };

  discord = pkgs.buildFHSEnv {
    name = "discord";
    pname = "discord";
    version = "1.0.157";
    executableName = "Discord";
    targetPkgs = pkgs: with pkgs; [
      alsa-lib atk at-spi2-atk at-spi2-core cairo cups dbus expat
      fontconfig freetype gdk-pixbuf glib gtk3 libglvnd libnotify
      libx11 libxcomposite libuuid libxdamage libxext libxfixes libxi
      libxrandr libxrender libxtst nspr nss libxcb libxkbcommon pango
      pipewire wayland libdrm libgbm libpulseaudio libcxx systemdLibs
      libva libxcursor libxscrnsaver libappindicator libdbusmenu
      stdenv.cc.cc
    ];
    runScript = "${discordUnwrapped}/opt/Discord/Discord";
    extraInstallCommands = ''
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp ${discordUnwrapped}/share/icons/hicolor/256x256/apps/discord.png \
        $out/share/icons/hicolor/256x256/apps/discord.png
      ln -s ${discordDesktopItem}/share/applications $out/share/applications
      ln -s $out/bin/Discord $out/bin/discord
    '';
  };

  discordApp = pkgs.writeShellScriptBin "discord-app" ''
    export HTTP_PROXY=http://127.0.0.1:2080
    export HTTPS_PROXY=http://127.0.0.1:2080
    export ALL_PROXY=http://127.0.0.1:2080
    exec ${discord}/bin/discord \
      --ozone-platform=wayland \
      --enable-features=UseOzonePlatform \
      --force-device-scale-factor=1 \
      "$@"
  '';
in
{
  inherit discord discordApp;
}
