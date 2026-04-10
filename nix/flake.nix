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

    # Pin devenv to v1.x
    # Note: Don't use follows here - devenv needs its own nixpkgs pin
    # to avoid lowdown 3.0 compatibility issues
    # See: https://github.com/cachix/devenv/issues/2553
    devenv.url = "github:cachix/devenv/v1.11.2";


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

      # Import builders
      builders = import ./lib/builders.nix {
        inherit nixpkgs nix-darwin home-manager nix-homebrew inputs self lib overlays overlaysList;
      };
    in
    {
      # Export overlays for external use
      inherit overlays;

      # NixOS configurations - automatically generated from registry
      nixosConfigurations = lib.mapAttrs builders.mkNixOSConfiguration nixosHosts;

      # macOS (nix-darwin) configurations - automatically generated from registry
      darwinConfigurations = lib.mapAttrs builders.mkDarwinConfiguration darwinHosts;

      # Standalone Home Manager configurations
      homeConfigurations = lib.mapAttrs builders.mkHomeConfiguration homeHosts;

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
