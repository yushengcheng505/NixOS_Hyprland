# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

let
  # Corrected DSDT for HONOR FMB-P BIOS 1.13; kept beside this file so builds
  # do not depend on network access to fetch the ACPI table.
  honorDsdt = ./dsdt.global.aml;

  honorDsdtInitrd = pkgs.runCommand "honor-fmbp-dsdt-initrd" {
    nativeBuildInputs = [ pkgs.cpio ];
  } ''
    mkdir -p root/kernel/firmware/acpi
    cp ${honorDsdt} root/kernel/firmware/acpi/dsdt.aml
    (cd root && find kernel -print | cpio -o -H newc --reproducible) > "$out"
  '';

  bluetoothConnectable = pkgs.writeShellScript "bluetooth-connectable" ''
    for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
      if ${pkgs.systemd}/bin/busctl set-property \
        org.bluez /org/bluez/hci0 org.bluez.Adapter1 Connectable b true; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.25
    done
    exit 1
  '';

  # Run Spotify as a native Wayland client.  This avoids blurry XWayland
  # scaling on the laptop's fractional-scale display.
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

  discordUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "discord-unwrapped";
    version = "1.0.157";
    src = ./discord-full.distro;
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
    comment = "All-in-one voice and text chat";
    exec = "discord -- %U";
    icon = "discord";
    categories = [ "Network" "InstantMessaging" ];
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

  chatgptUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-unwrapped";
    version = "26.901.51231";
    src = ./chatgpt_amd64.deb;
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
    comment = "ChatGPT by OpenAI";
    exec = "chatgpt --proxy-server=http://127.0.0.1:2080 %U";
    icon = "chatgpt";
    categories = [ "Utility" "Development" ];
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
      mesa mesa.drivers
      stdenv.cc.cc
    ];
    runScript = pkgs.writeShellScript "chatgpt-run" ''
      export HTTP_PROXY="http://127.0.0.1:2080"
      export HTTPS_PROXY="http://127.0.0.1:2080"
      export ALL_PROXY="http://127.0.0.1:2080"
      export NO_PROXY="127.0.0.1,localhost,::1"
      exec ${chatgptUnwrapped}/usr/lib/chatgpt/ChatGPT \
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

  throne = pkgs.stdenvNoCC.mkDerivation {
    pname = "throne";
    version = "1.2.4";
    src = pkgs.fetchzip {
      url = "https://github.com/throneproj/Throne/releases/download/1.2.4/Throne-1.2.4-linux-amd64.zip";
      sha256 = "b5ff75aed3633d6f146921ebb75f232e0f0b5a2eca878a701e73bd232f1dd838";
    };
    nativeBuildInputs = [ pkgs.makeWrapper pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      stdenv.cc.cc
      zstd
      dbus
      glib
      krb5
      openssl
      gtk3
      pango
      cairo
      atk
      gdk-pixbuf
      harfbuzz
      fontconfig
      freetype
      libGL
      libxkbcommon
      wayland
      xorg.libX11
      xorg.libXcursor
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libxcb
      xorg.xcbutilcursor
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
    ];
    autoPatchelfIgnoreMissingDeps = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/opt/Throne $out/share/icons/hicolor/512x512/apps $out/share/applications
      cp -r . $out/opt/Throne/
      chmod +x $out/opt/Throne/Throne $out/opt/Throne/ThroneCore
      cp $out/opt/Throne/Throne.png $out/share/icons/hicolor/512x512/apps/throne.png
      cp ${throneDesktopItem}/share/applications/throne.desktop $out/share/applications/
      makeWrapper $out/opt/Throne/Throne $out/bin/throne \
        --chdir $out/opt/Throne \
        --prefix PATH : $out/opt/Throne \
        --set QT_PLUGIN_PATH $out/opt/Throne/usr/plugins \
        --set LD_LIBRARY_PATH "$out/opt/Throne/usr/lib:${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc pkgs.zstd pkgs.dbus pkgs.glib pkgs.krb5 pkgs.openssl pkgs.gtk3 pkgs.pango pkgs.cairo pkgs.atk pkgs.gdk-pixbuf pkgs.harfbuzz pkgs.fontconfig pkgs.freetype pkgs.libGL pkgs.libxkbcommon pkgs.wayland pkgs.xorg.libX11 pkgs.xorg.libXcursor pkgs.xorg.libXext pkgs.xorg.libXfixes pkgs.xorg.libXi pkgs.xorg.libXrandr pkgs.xorg.libXrender pkgs.xorg.libxcb pkgs.xorg.xcbutilcursor pkgs.xorg.xcbutilimage pkgs.xorg.xcbutilkeysyms pkgs.xorg.xcbutilrenderutil ]}"
    '';
    meta = {
      description = "Cross-platform GUI proxy utility powered by sing-box";
      homepage = "https://github.com/throneproj/Throne";
      license = pkgs.lib.licenses.gpl2Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "throne";
    };
  };

  throneDesktopItem = pkgs.makeDesktopItem {
    name = "throne";
    desktopName = "Throne";
    exec = "throne -appdata";
    icon = "throne";
    categories = [ "Network" ];
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
  # Keep the user's Hyprland configuration linked to the tracked dotfiles.
  system.activationScripts.hyprlandConfigLink = {
    deps = [ "users" ];
    text = ''
      hyprlandSource="/etc/nixos/dotfiles/hypr"
      hyprlandTarget="/home/klenko/.config/hypr"

      if [ -L "$hyprlandTarget" ]; then
        target=$(readlink "$hyprlandTarget")
        if [ "$target" != "$hyprlandSource" ]; then
          echo "Refusing to replace $hyprlandTarget: unexpected symlink target $target" >&2
          exit 1
        fi
      elif [ -e "$hyprlandTarget" ]; then
        echo "Refusing to replace existing $hyprlandTarget; move it aside before switching." >&2
        exit 1
      else
        ln -s "$hyprlandSource" "$hyprlandTarget"
      fi
    '';
  };

  # Keep the user's Quickshell configuration linked to the tracked dotfiles.
  system.activationScripts.quickshellConfigLink = {
    deps = [ "users" ];
    text = ''
      quickshellSource="/etc/nixos/dotfiles/quickshell/cartoon-shell"
      quickshellTarget="/home/klenko/.config/quickshell/cartoon-shell"

      if [ -L "$quickshellTarget" ]; then
        target=$(readlink "$quickshellTarget")
        if [ "$target" != "$quickshellSource" ]; then
          echo "Refusing to replace $quickshellTarget: unexpected symlink target $target" >&2
          exit 1
        fi
      elif [ -e "$quickshellTarget" ]; then
        echo "Refusing to replace existing $quickshellTarget; move it aside before switching." >&2
        exit 1
      else
        mkdir -p "$(dirname "$quickshellTarget")"
        ln -s "$quickshellSource" "$quickshellTarget"
      fi
    '';
  };

  imports =
    [       ./hyprland-honor-fmbp/module.nix
# Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  services.openssh.enable = true;

  # Enable the modern Nix CLI and flake support system-wide.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Provide the BlueZ D-Bus service used by Quickshell's Bluetooth module.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Quickshell does not provide a BlueZ agent of its own. Allow
        # headless/Just Works pairing requests instead of rejecting them.
        AlwaysPairable = true;
        JustWorksRepairing = "always";
      };
    };
  };

  # BlueZ 5.87 leaves this adapter non-connectable on power-up even though it
  # is powered and pairable. Set the Adapter1 property through D-Bus after the
  # daemon has registered its controller.
  systemd.services.bluetooth.serviceConfig.ExecStartPost =
    bluetoothConnectable;

  networking.firewall.allowedTCPPorts = [ 22 ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.prepend = [ "${honorDsdtInitrd}" ];
  # Keep the PS/2 keyboard writable so the kernel can control Caps Lock LEDs.
  # The previous i8042.dumbkbd=1 workaround disabled those LED commands.
  boot.kernelParams = [ "i915.enable_psr=0" ];
  boot.kernelModules = [ "i8042" "tun" ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  services.logind.settings.Login.IdleAction = "ignore";

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Moscow";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Use SDDM as the display manager for the Wayland session.
  services.displayManager.sddm.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:alt_shift_toggle";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # Use the WirePlumber session manager
    #wireplumber.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # FocalTech FTSC1000 exposes a vendor data collection that Linux misreads
  # as KEY_MICMUTE; block only that phantom input node.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="input*", ATTR{name}=="FTSC1000:00 2808:5662 UNKNOWN", ATTR{inhibited}="1"
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="FTSC1000:00 2808:5662 UNKNOWN", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';

  security.polkit.enable = true;
  security.polkit.enablePkexecWrapper = true;
  # Permit the local active desktop user to use the power controls from the
  # Quickshell launcher without an unavailable terminal authentication prompt.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var powerActions = [
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions",
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions",
        "org.freedesktop.login1.suspend",
        "org.freedesktop.login1.suspend-multiple-sessions",
        "org.freedesktop.login1.hibernate",
        "org.freedesktop.login1.hibernate-multiple-sessions"
      ];
      if (subject.user == "klenko" && powerActions.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  programs.throne = {
    enable = true;
    package = pkgs.throne;
    tunMode.enable = false;
  };

  systemd.user.services.throne-pac = {
    unitConfig = {
      Description = "Serve the Throne PAC file for Chromium browsers";
      After = [ "graphical-session.target" ];
    };
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${thronePacDir} --addr 127.0.0.1 --port 18765 --no-listing";
      Restart = "on-failure";
      RestartSec = 1;
    };
    wantedBy = [ "default.target" ];
  };


  environment.systemPackages = [
    discord
    pkgs.telegram-desktop
    pkgs.codex
    chatgpt
    pkgs.zed-editor
    spotifyWayland
    pkgs.nodejs
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
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."klenko" = {
    isNormalUser = true;
    description = "Klenko";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
