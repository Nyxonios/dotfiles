{
  description = "Work Darwin System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    pkgs-tmux-catppuccin-pin.url = "github:NixOS/nixpkgs/50165c4f7eb48ce82bd063e1fb8047a0f515f8ce";


    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    zig.url = "github:mitchellh/zig-overlay";
    zls.url = "github:zigtools/zls";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, zig, zls, pkgs-tmux-catppuccin-pin, nix-darwin, nix-homebrew, home-manager, ... } @ inputs:
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
      common-home-manager = {
        home-manager.extraSpecialArgs = {
          inherit inputs;
          inherit pkgs-catppuccin-pin;
          inherit pkgs-stable;
        };
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "before-nix-backup";
        home-manager.users."${userData.user}" = import ./home.nix;
      };

      pkgs = import nixpkgs {
        inherit system;
        config = common-pkgs-config;
      };
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config = common-pkgs-config;
      };
      pkgs-catppuccin-pin = import pkgs-tmux-catppuccin-pin {
        inherit system;
        config = common-pkgs-config;
      };
    in
    {
      # Build darwin flake using:
      darwinConfigurations."work" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          inherit pkgs-catppuccin-pin;
          inherit pkgs-stable;
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
            nixpkgs.overlays = [
              zig.overlays.default
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
          system = system;
          specialArgs = { inherit inputs; inherit pkgs-catppuccin-pin; };
          modules = [
            ./hosts/nixos/configuration.nix
            home-manager.nixosModules.home-manager
            common-home-manager
            {
              nixpkgs.overlays = [
                zig.overlays.default
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

      homeConfigurations."vm" = home-manager.lib.homeManagerConfiguration
        {
          extraSpecialArgs = {
            inherit inputs;
            inherit pkgs-catppuccin-pin;
            inherit pkgs-stable;
          };
          pkgs = pkgs;
          modules = [
            {
              nixpkgs.overlays = [
                zig.overlays.default
              ];
            }
            (import ./hosts/vm/configuration.nix)
            (import ./home.nix)
          ];
        };
    };
}

