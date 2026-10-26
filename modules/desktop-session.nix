{ config, pkgs, desktopApps, ... }:

let
  desktopConfigLink = relativePath: entrypoint: {
    deps = [ "users" ];
    text = ''
      (
        set -eu
        source="/home/klenko/nixos/dotfiles/${relativePath}"
        legacySource="/etc/nixos/dotfiles/${relativePath}"
        target="${config.users.users.klenko.home}/.config/${relativePath}"

        if [ ! -f "$source/${entrypoint}" ]; then
          echo "Missing desktop configuration: $source/${entrypoint}" >&2
          exit 1
        fi

        if [ -L "$target" ]; then
          current=$(readlink "$target")
          if [ "$current" = "$source" ]; then
            exit 0
          elif [ "$current" != "$legacySource" ]; then
            echo "Refusing to replace $target: unexpected symlink target $current" >&2
            exit 1
          fi
        elif [ -e "$target" ]; then
          echo "Refusing to replace existing $target; move it aside before switching." >&2
          exit 1
        fi

        for directory in "${config.users.users.klenko.home}/.config" "$(dirname "$target")"; do
          if [ ! -d "$directory" ]; then
            install -d -m 0700 -o klenko -g ${config.users.users.klenko.group} "$directory"
          fi
        done
        ln -sfnT "$source" "$target"
        chown -h klenko:${config.users.users.klenko.group} "$target"
      )
    '';
  };

  hypridleConfig = pkgs.writeText "hypridle-direct.conf" ''
    listener {
      timeout = 900
      on-timeout = ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
      on-resume = ${config.programs.hyprland.package}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
    }
  '';
in
{
  system.activationScripts.hyprlandConfigLink = desktopConfigLink "hypr" "hyprland.lua";
  system.activationScripts.quickshellConfigLink = desktopConfigLink "quickshell/cartoon-shell" "shell.qml";
  services.logind.settings.Login.IdleAction = "ignore";
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:alt_shift_toggle";
  };

  systemd.user.targets.hyprland-session = {
    unitConfig = {
      Description = "Hyprland direct session (Wayland environment imported)";
      DefaultDependencies = false;
      BindsTo = [ "graphical-session.target" ];
      After = [ "default.target" "graphical-session.target" ];
    };
  };

  systemd.user.services.quickshell = {
    path = [ config.system.path ];
    unitConfig = {
      Description = "Quickshell Cartoon Shell";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      Requisite = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      Environment = [
        "LANG=en_US.UTF-8"
        "LANGUAGE=en_US:en"
        "LC_ALL=en_US.UTF-8"
        "QML2_IMPORT_PATH=/run/current-system/sw/lib/qt-6/qml"
        "QML_IMPORT_PATH=/run/current-system/sw/lib/qt-6/qml"
        "QT_QPA_PLATFORM=wayland"
        "QT_QPA_PLATFORMTHEME=gtk3"
        "QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi"
        "QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi"
      ];
      ExecStart = "${pkgs.quickshell}/bin/quickshell -n -p %h/.config/quickshell/cartoon-shell";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "hyprland-session.target" ];
  };

  systemd.user.services.hypridle-direct = {
    unitConfig = {
      Description = "Turn off displays after 15 minutes of inactivity";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      Requisite = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle -c ${hypridleConfig}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "hyprland-session.target" ];
  };

  systemd.user.services.easycliproxyapi = {
    unitConfig = {
      Description = "EasyCLIProxyAPI desktop console";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      Requisite = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      Environment = [
        "GSETTINGS_SCHEMA_DIR=${pkgs.glib.getSchemaPath pkgs.gsettings-desktop-schemas}"
      ];
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${desktopApps.easycliproxyapi}/bin/easycliproxyapi";
      ExitType = "cgroup";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "hyprland-session.target" ];
  };
}
