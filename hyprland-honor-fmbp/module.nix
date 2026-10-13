{ lib, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };


  programs.uwsm.waylandCompositors.hyprland = {
    prettyName = "Hyprland";
    comment = "Hyprland compositor managed by UWSM";
    binPath = "/run/current-system/sw/bin/Hyprland";
  };

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  systemd.user.services.xdg-desktop-portal-hyprland-direct = {
    unitConfig = {
      Description = "Hyprland desktop portal for direct sessions";
    };
    serviceConfig = {
      ExecStart = "${pkgs.xdg-desktop-portal-hyprland}/libexec/xdg-desktop-portal-hyprland";
      Restart = "on-failure";
      RestartSec = 2;
    };
    wantedBy = [ "default.target" ];
  };

  systemd.user.services.xdg-desktop-portal-direct = {
    unitConfig = {
      Description = "XDG desktop portal for direct Hyprland sessions";
    };
    serviceConfig = {
      ExecStart = "${pkgs.xdg-desktop-portal}/libexec/xdg-desktop-portal";
      Restart = "always";
      RestartSec = 2;
    };
    wantedBy = [ "default.target" ];
  };

  # The laptop uses Intel i915/Arc graphics; this keeps VA-API and Wayland
  # acceleration available without adding NVIDIA-specific settings.
  # Provides battery state to Quickshell and WirePlumber.
  services.upower.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  environment.systemPackages = with pkgs; [
      fastfetch
      dotool
      app2unit
    quickshell
    kitty
    nautilus
    brightnessctl
    wl-clipboard
    grim
    slurp
    jq
    bc
    cava
    playerctl
    libnotify
    imagemagick
    ffmpeg
    sysstat
    networkmanagerapplet
    pwvucontrol
    qpwgraph
    helvum
    matugen
    fish
    starship
    papirus-icon-theme
    bibata-cursors
    adw-gtk3
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qt5compat
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtimageformats
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.comic-shanns-mono
    nerd-fonts.symbols-only
    material-symbols
    noto-fonts-cjk-sans
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Classic";
    HYPRCURSOR_SIZE = "24";
  };
}
