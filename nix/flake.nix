{
  description = "Work Darwin System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Removed: nixpkgs-stable and pkgs-tmux-catppuccin-pin - now using overlays instead

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls";
  };

  outputs = { self, nixpkgs, zig, zls, nix-darwin, nix-homebrew, home-manager, ... } @ inputs:
    let
      inherit (import ./vars.nix { pkgs = nixpkgs; }) userData;
      system = userData.platform;

      common-pkgs-config = {
        allowUnfree = true;
        permittedInsecurePackages = [ ];
      };
      commonModules = [
        { nixpkgs.config.allowUnfree = true; }
        { nixpkgs.config.permittedInsecurePackages = [ ]; }
      ];

      # Import all overlays from the overlays directory
      overlays = import ./overlays { inherit inputs system; };

      pkgs = import nixpkgs {
        inherit system;
        config = common-pkgs-config;
        overlays = overlays.allOverlays;
      };

      common-home-manager = {
        home-manager.extraSpecialArgs = {
          inherit inputs;
        };
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "before-nix-backup";
        home-manager.users."${userData.user}" = import ./home.nix;
      };
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
          common-home-manager
          {
            nixpkgs.overlays = overlays.allOverlays;
          }
        ] ++ commonModules;
      };
      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."work".pkgs;


      nixosConfigurations."${userData.user}" = nixpkgs.lib.nixosSystem
        {
          system = system;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/nixos/configuration.nix
            home-manager.nixosModules.home-manager
            common-home-manager
            {
              nixpkgs.overlays = overlays.allOverlays;
            }
          ] ++ commonModules;
        };

      homeConfigurations."vm" = home-manager.lib.homeManagerConfiguration
        {
          extraSpecialArgs = {
            inherit inputs;
          };
          pkgs = pkgs;
          modules = [
            {
              nixpkgs.overlays = overlays.allOverlays;
            }
            (import ./hosts/vm/configuration.nix)
            (import ./home.nix)
          ];
        };
    };
}
