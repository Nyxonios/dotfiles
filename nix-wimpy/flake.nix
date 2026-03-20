{
  description = "Nix Configuration inspired by wimpysworld/nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/HyprLand";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, nix-homebrew, home-manager, ... } @ inputs:
    let
      # Import the noughty module system for host metadata
      lib = nixpkgs.lib // (import ./lib { inherit nixpkgs; });

      # System registry from TOML file
      systems = lib.systems.loadFromTOML ./systems.toml;

      # Helper to generate nixosConfigurations from registry
      nixosHosts = lib.systems.getNixOSHosts systems;

      # Helper to generate darwinConfigurations from registry
      darwinHosts = lib.systems.getDarwinHosts systems;

      # Helper to generate homeConfigurations from registry
      homeHosts = lib.systems.getHomeManagerHosts systems;

      # Common overlays
      overlays = import ./overlays { inherit inputs; };

      # Common nixpkgs configuration
      nixpkgsConfig = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
    in
    {
      # NixOS configurations - automatically generated from registry
      nixosConfigurations = lib.mapAttrs (hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit (system) system;
          specialArgs = {
            inherit inputs lib overlays;
            host = system;
          };
          modules = [
            # Include all nixos mixins (self-gating modules)
            ./nixos
            # Host-specific hardware configuration
            ./hosts/${hostname}
            # Home Manager integration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "before-nix-backup";
                extraSpecialArgs = {
                  inherit inputs lib overlays;
                  host = system;
                };
                users.${system.username} = import ./home-manager;
              };
            }
            {
              nixpkgs = {
                inherit overlays;
                config = nixpkgsConfig;
              };
            }
          ];
        }
      ) nixosHosts;

      # macOS (nix-darwin) configurations - automatically generated from registry
      darwinConfigurations = lib.mapAttrs (hostname: system:
        nix-darwin.lib.darwinSystem {
          inherit (system) system;
          specialArgs = {
            inherit inputs lib overlays;
            host = system;
          };
          modules = [
            # Include all darwin mixins (self-gating modules)
            ./darwin
            # Host-specific configuration
            ./hosts/${hostname}
            # nix-homebrew integration
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                user = system.username;
              };
            }
            # Home Manager integration
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "before-nix-backup";
                extraSpecialArgs = {
                  inherit inputs lib overlays;
                  host = system;
                };
                users.${system.username} = import ./home-manager;
              };
            }
            {
              nixpkgs = {
                inherit overlays;
                config = nixpkgsConfig;
              };
            }
          ];
        }
      ) darwinHosts;

      # Standalone Home Manager configurations
      homeConfigurations = lib.mapAttrs (hostname: system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit (system) system;
            inherit overlays;
            config = nixpkgsConfig;
          };
          extraSpecialArgs = {
            inherit inputs lib overlays;
            host = system;
          };
          modules = [
            ./home-manager
            {
              home = {
                inherit (system) username;
                homeDirectory = system.home;
                stateVersion = "24.05";
              };
            }
          ];
        }
      ) homeHosts;

      # Expose package sets for convenience
      packages = lib.mapAttrs (system: _: {
        # Default packages can be added here
      }) nixpkgs.legacyPackages;
    };
}
