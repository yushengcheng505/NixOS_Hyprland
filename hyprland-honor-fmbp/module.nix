{ config, lib, pkgs, ... }:

let
  sessionSupervisor = pkgs.writeShellApplication {
    name = "hyprland-session-supervisor";
    runtimeInputs = [ pkgs.util-linux pkgs.systemd pkgs.coreutils ];
    text = builtins.readFile ./hyprland-session.sh;
  };
  sessionLauncher = pkgs.writeShellApplication {
    name = "hyprland-session";
    text = ''
      exec ${lib.getExe sessionSupervisor} ${config.programs.hyprland.package}/bin/start-hyprland "$@"
    '';
  };
  sessionReady = pkgs.writeShellApplication {
    name = "hyprland-session-ready";
    runtimeInputs = [ pkgs.util-linux pkgs.systemd pkgs.dbus pkgs.coreutils ];
    text = builtins.readFile ./hyprland-session-ready.sh;
  };
  sessionDesktop = pkgs.runCommand "hyprland-direct-session" {
    passthru.providedSessions = [ "hyprland" ];
  } ''
    mkdir -p "$out/share/wayland-sessions"
    cat > "$out/share/wayland-sessions/hyprland.desktop" <<EOF
    [Desktop Entry]
    Name=Hyprland
    Comment=An intelligent dynamic tiling Wayland compositor
    Exec=${lib.getExe sessionLauncher}
    Type=Application
    DesktopNames=Hyprland
    Keywords=tiling;wayland;compositor;
    EOF
  '';
  portalService = {
    overrideStrategy = "asDropin";
    unitConfig = {
      Requisite = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
    wantedBy = [ "hyprland-session.target" ];
  };
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = false;
    xwayland.enable = true;
  };

  services.dbus.implementation = "broker";
  services.displayManager.sessionPackages = lib.mkForce [ sessionDesktop ];

  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-hyprland ];
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  systemd.user.services = {
    xdg-desktop-portal = portalService;
    xdg-desktop-portal-hyprland = portalService;
    xdg-desktop-portal-gtk = portalService;
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
    sessionReady
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
