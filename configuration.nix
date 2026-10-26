{ pkgs, discordArchive, chatgptArchive, ... }:

{
  imports = [
    ./modules/applications.nix
    ./hyprland-honor-fmbp/module.nix
    ./hardware-configuration.nix
    ./modules/hardware-honor.nix
    ./modules/maintenance.nix
    ./modules/bluetooth.nix
    ./modules/networking.nix
    ./modules/desktop-session.nix
    ./modules/package-manifest.nix
  ];

  _module.args.desktopApps = import ./pkgs/desktop-apps.nix {
    inherit pkgs discordArchive chatgptArchive;
  };

  time.timeZone = "Europe/Moscow";
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

  services.printing.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  security.polkit.enable = true;
  security.polkit.enablePkexecWrapper = true;
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
      if (subject.user == "klenko" && subject.local && subject.active && powerActions.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  users.users."klenko" = {
    isNormalUser = true;
    description = "Klenko";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [ ];
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";
}
