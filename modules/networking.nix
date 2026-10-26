{ pkgs, desktopApps, ... }:

{
  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  programs.throne = {
    enable = true;
    package = pkgs.throne;
    tunMode.enable = false;
  };

  systemd.user.services.throne-pac = {
    unitConfig = {
      Description = "Serve the Throne PAC file for Chromium browsers";
      ConditionUser = "klenko";
    };
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${desktopApps.thronePacDir} --addr 127.0.0.1 --port 18765 --no-listing";
      Restart = "on-failure";
      RestartSec = 1;
    };
    wantedBy = [ "default.target" ];
  };
}
