{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        AlwaysPairable = false;
        JustWorksRepairing = "confirm";
        PairableTimeout = 120;
      };
    };
  };

  services.blueman.enable = true;
  systemd.user.services.blueman-applet = {
    overrideStrategy = "asDropin";
    unitConfig = {
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      Requisite = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      Environment = [
        "GSETTINGS_SCHEMA_DIR=${pkgs.blueman}/share/gsettings-schemas/${pkgs.blueman.name}/glib-2.0/schemas"
      ];
      ExecStartPre = "${pkgs.glib}/bin/gsettings set org.blueman.general plugin-list \"['!TransferService', '!ConnectionNotifier', '!AutoConnect', '!DiscvManager']\"";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "hyprland-session.target" ];
  };

  systemd.user.services.obex.enable = false;
}
