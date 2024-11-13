{
  description = "Work Darwin System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew, home-manager, zig }:
    let
      inherit (import ./vars.nix { pkgs = nixpkgs; }) userData;
    in
    {
      # Build darwin flake using:
      darwinConfigurations."work" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/darwin/configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "${userData.user}";
            };
          }
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-nix-backup";
            home-manager.users."${userData.user}" = import ./home.nix;
          }
          { nixpkgs.overlays = [ zig.overlays.default ]; }
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."work".pkgs;
    };
}

