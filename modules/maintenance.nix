{ ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "Sun *-*-* 15:17:00";
    randomizedDelaySec = "30min";
    options = "";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "Sun *-*-* 16:17:00" ];
    randomizedDelaySec = "30min";
  };
}
