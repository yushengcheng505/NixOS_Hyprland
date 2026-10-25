{
  description = "NixOS configuration for the Honor FMB-P laptop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    discordArchive = {
      url = "file+file:///home/klenko/nixos/discord-full.distro";
      flake = false;
    };
    chatgptArchive = {
      url = "file+file:///home/klenko/nixos/chatgpt_amd64.deb";
      flake = false;
    };
  };

  outputs = { nixpkgs, discordArchive, chatgptArchive, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          discordArchive = builtins.path {
            path = discordArchive.outPath;
            name = "discord-full.distro";
          };
          chatgptArchive = builtins.path {
            path = chatgptArchive.outPath;
            name = "chatgpt_amd64.deb";
          };
        };
        modules = [ ./configuration.nix ];
      };
    };
}
