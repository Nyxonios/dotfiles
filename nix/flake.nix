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
      # Import the module system for host metadata
      lib = nixpkgs.lib // (import ./lib { inherit nixpkgs; });

      # System registry from TOML file
      systems = lib.loadFromTOML ./systems.toml;

      # Helper to generate nixosConfigurations from registry
      nixosHosts = lib.getNixOSHosts systems;

      # Helper to generate darwinConfigurations from registry
      darwinHosts = lib.getDarwinHosts systems;

      # Helper to generate homeConfigurations from registry
      homeHosts = lib.getHomeManagerHosts systems;

      # Import overlays as an attribute set (following wimpysworld pattern)
      overlays = import ./overlays { inherit inputs; };

      # Convert overlays to list for nixpkgs
      overlaysList = builtins.attrValues overlays;

      # Common nixpkgs configuration
      nixpkgsConfig = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
    in
    {
      # Export overlays for external use
      inherit overlays;

      # NixOS configurations - automatically generated from registry
      nixosConfigurations = lib.mapAttrs
        (hostname: system:
          nixpkgs.lib.nixosSystem {
            inherit (system) system;
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
              host = system;
              customLib = lib;
            };
            modules = [
              # Common configuration (overlays, nix settings, etc.)
              ./platforms/common
              # Include all nixos mixins (self-gating modules)
              ./platforms/nixos
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
                    inherit inputs overlays;
                    inherit (self) outputs;
                    host = system;
                    customLib = lib;
                  };
                  users.${system.username} = import ./platforms/home-manager;
                };
              }
            ];
          }
        )
        nixosHosts;

      # macOS (nix-darwin) configurations - automatically generated from registry
      darwinConfigurations = lib.mapAttrs
        (hostname: system:
          nix-darwin.lib.darwinSystem {
            inherit (system) system;
            specialArgs = {
              inherit inputs;
              inherit (self) outputs;
              host = system;
              customLib = lib;
            };
            modules = [
              # Common configuration (overlays, nix settings, etc.)
              ./platforms/common
              # Include all darwin mixins (self-gating modules)
              ./platforms/darwin
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
                    inherit inputs overlays;
                    inherit (self) outputs;
                    host = system;
                    customLib = lib;
                  };
                  users.${system.username} = import ./platforms/home-manager;
                };
              }
            ];
          }
        )
        darwinHosts;

      # Standalone Home Manager configurations
      homeConfigurations = lib.mapAttrs
        (hostname: system:
          home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit (system) system;
              overlays = overlaysList;
              config = nixpkgsConfig;
            };
            extraSpecialArgs = {
              inherit inputs overlays;
              inherit (self) outputs;
              host = system;
              # Pass our custom lib functions as customLib
              customLib = import ./lib { nixpkgs = { inherit (nixpkgs) lib; }; };
            };
            modules = [
              ./platforms/home-manager
              {
                home = {
                  inherit (system) username;
                  homeDirectory = system.home;
                  stateVersion = "24.05";
                };
              }
            ];
          }
        )
        homeHosts;

      # Expose package sets for convenience
      packages = lib.mapAttrs
        (system: _: {
          # Default packages can be added here
        })
        nixpkgs.legacyPackages;

      # Development shell with necessary tools
      devShells = lib.mapAttrs
        (system: pkgs: {
          default = pkgs.mkShell {
            name = "nix-dev";

            packages = with pkgs; [
              git
              just
              nixpkgs-fmt
            ];

            shellHook = ''
              echo "🧊 Nix Development Shell"
              echo ""
              echo "Available commands:"
              echo "  just              - Show available recipes"
              echo ""
            '';
          };
        })
        nixpkgs.legacyPackages;
    };
}
