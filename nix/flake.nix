{
  description = "Work Darwin System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-overlay.url = "github:zigtools/zls";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew, home-manager, ... }:
    let
      inherit (import ./vars.nix { pkgs = nixpkgs; }) userData;
      system = userData.platform;
      pkgs = nixpkgs.legacyPackages.${system};

      # Define the shared module here once
      commonModules = [
        { nixpkgs.config.allowUnfree = true; }
        { nix.optimise.automatic = true; }
      ];
    in
    {
      # Build darwin flake using:
      darwinConfigurations."work" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/darwin/configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "${userData.user}";
            };
          }
          home-manager.darwinModules.home-manager
          {
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-nix-backup";
            home-manager.users."${userData.user}" = import ./home.nix;
          }
          {
            nixpkgs.overlays = [
              (self: super: {
                karabiner-elements = super.karabiner-elements.overrideAttrs (old: {
                  version = "14.13.0";

                  src = super.fetchurl {
                    inherit (old.src) url;
                    hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
                  };
                });
              })
            ];
          } 
        ] ++ commonModules;
      };
      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."work".pkgs;


      nixosConfigurations."${userData.user}" = nixpkgs.lib.nixosSystem
        {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/nixos/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "before-nix-backup";
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users."${userData.user}" = import ./home.nix;
            }
          ] ++ commonModules;
        };

      homeConfigurations."vm" = home-manager.lib.homeManagerConfiguration
        {
          extraSpecialArgs = { inherit inputs; };
          pkgs = pkgs;
          modules = [
            (import ./home.nix)
          ] ++ commonModules;
        };
    };
}

