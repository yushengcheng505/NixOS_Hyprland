{ pkgs, chatgptArchive }:

let
  chatgptUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-unwrapped";
    version = "26.901.51231";
    src = chatgptArchive;
    nativeBuildInputs = [ pkgs.dpkg ];
    dontUnpack = true;
    installPhase = ''
      dpkg-deb -x $src $out
      chmod +x $out/usr/lib/chatgpt/ChatGPT $out/usr/lib/chatgpt/codex-launcher
    '';
  };

  chatgptDesktopItem = pkgs.makeDesktopItem {
    name = "chatgpt";
    desktopName = "ChatGPT";
    genericName = "AI assistant";
    comment = "ChatGPT by OpenAI (software rendering)";
    exec = "chatgpt-safe %U";
    tryExec = "chatgpt-safe";
    icon = "chatgpt";
    startupNotify = true;
    categories = [ "Utility" "Development" ];
    mimeTypes = [
      "x-scheme-handler/codex"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "text/csv"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      "text/tab-separated-values"
      "application/vnd.ms-excel"
      "application/vnd.ms-excel.sheet.macroEnabled.12"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ];
  };

  chatgpt = pkgs.buildFHSEnv {
    name = "chatgpt";
    pname = "chatgpt";
    version = "26.901.51231";
    executableName = "ChatGPT";
    targetPkgs = pkgs: with pkgs; [
      alsa-lib atk at-spi2-atk at-spi2-core cairo cups dbus expat
      fontconfig freetype gdk-pixbuf glib gtk3 libglvnd libnotify
      libdrm libgbm libudev0-shim libusb1 libx11 libxcb
      libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr
      nspr nss pango pipewire pulseaudio wayland xdg-utils xz
      systemdLibs
      mesa
      stdenv.cc.cc
    ];
    runScript = pkgs.writeShellScript "chatgpt-run" ''
      export HTTP_PROXY="http://127.0.0.1:2080"
      export HTTPS_PROXY="http://127.0.0.1:2080"
      export ALL_PROXY="http://127.0.0.1:2080"
      export NO_PROXY="127.0.0.1,localhost,::1"
      exec ${chatgptUnwrapped}/usr/lib/chatgpt/ChatGPT \
        --ozone-platform=wayland \
        --enable-features=UseOzonePlatform,WaylandFractionalScalingV1 \
        --force-device-scale-factor=1 \
        --proxy-server=http://127.0.0.1:2080 "$@"
    '';
    extraInstallCommands = ''
      mkdir -p $out/share/icons/hicolor/512x512/apps $out/share/pixmaps
      cp ${chatgptUnwrapped}/usr/share/pixmaps/chatgpt.png $out/share/pixmaps/chatgpt.png
      cp ${chatgptUnwrapped}/usr/share/pixmaps/chatgpt.png \
        $out/share/icons/hicolor/512x512/apps/chatgpt.png
      ln -s ${chatgptDesktopItem}/share/applications $out/share/applications
      ln -s $out/bin/ChatGPT $out/bin/chatgpt
    '';
  };

  chatgptSafe = pkgs.writeShellScriptBin "chatgpt-safe" ''
    exec ${chatgpt}/bin/chatgpt \
      --disable-gpu \
      --disable-gpu-compositing \
      --disable-gpu-rasterization \
      --ozone-platform=wayland \
      --enable-features=UseOzonePlatform,WaylandFractionalScalingV1 \
      --force-device-scale-factor=1 \
      --proxy-server=http://127.0.0.1:2080 \
      "$@"
  '';
in
{
  inherit chatgpt chatgptSafe;
}
