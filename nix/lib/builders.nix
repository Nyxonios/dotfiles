# Configuration Builders
# Extracted from flake.nix to reduce boilerplate

{ nixpkgs, nix-darwin, home-manager, nix-homebrew, inputs, self, lib, overlays, overlaysList }:

let
  # Common specialArgs used across all configurations
  mkSpecialArgs = host: {
    inherit inputs overlays;
    inherit (self) outputs;
    inherit host;
    customLib = lib;
  };

  # Common Home Manager settings
  mkHomeManagerSettings = system: {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "before-nix-backup";
    extraSpecialArgs = mkSpecialArgs system;
    users.${system.username} = import ../platforms/home-manager;
  };

  # Build a NixOS configuration from host metadata
  mkNixOSConfiguration = hostname: system:
    nixpkgs.lib.nixosSystem {
      inherit (system) system;
      specialArgs = mkSpecialArgs system;
      modules = [
        ../platforms/common
        ../platforms/nixos
        ../hosts/${hostname}
        home-manager.nixosModules.home-manager
        { home-manager = mkHomeManagerSettings system; }
      ];
    };

  # Build a Darwin configuration from host metadata
  mkDarwinConfiguration = hostname: system:
    nix-darwin.lib.darwinSystem {
      inherit (system) system;
      specialArgs = mkSpecialArgs system;
      modules = [
        ../platforms/common
        ../platforms/darwin
        ../hosts/${hostname}
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = system.username;
          };
        }
        home-manager.darwinModules.home-manager
        { home-manager = mkHomeManagerSettings system; }
      ];
    };

  # Build a standalone Home Manager configuration from host metadata
  mkHomeConfiguration = hostname: system:
    home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit (system) system;
        overlays = overlaysList;
        config = { allowUnfree = true; };
      };
      extraSpecialArgs = mkSpecialArgs system;
      modules = [
        ../platforms/home-manager
        {
          home = {
            inherit (system) username;
            homeDirectory = system.home;
            stateVersion = "24.05";
          };
        }
      ];
    };

in
{
  inherit mkNixOSConfiguration mkDarwinConfiguration mkHomeConfiguration mkSpecialArgs;
}
