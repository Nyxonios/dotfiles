{
  description = "Work Darwin System Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

  outputs = { self, nixpkgs, zig, zls, pkgs-tmux-catppuccin-pin, nix-darwin, nix-homebrew, home-manager, ... } @ inputs:
    let
      inherit (import ./vars.nix { pkgs = nixpkgs; }) userData;
      system = userData.platform;
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-catppuccin-pin = pkgs-tmux-catppuccin-pin.legacyPackages.${system};

      # Define the shared module here once
      commonModules = [
        { nixpkgs.config.allowUnfree = true; }
        { nixpkgs.config.permittedInsecurePackages = [ ]; }
      ];
    in
    {
      # Build darwin flake using:
      darwinConfigurations."work" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          inherit pkgs-catppuccin-pin;
          # inherit zig;
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
            home-manager.extraSpecialArgs = {
              inherit inputs;
              inherit pkgs-catppuccin-pin;
            };
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-nix-backup";
            home-manager.users."${userData.user}" = import ./home.nix;
          }
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
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "before-nix-backup";
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit pkgs-catppuccin-pin;
              };
              home-manager.users."${userData.user}" = import ./home.nix;
            }
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
          };
          pkgs = pkgs;
          modules = [
            (import ./hosts/vm/configuration.nix)
            (import ./home.nix)
          ] ++ commonModules;
        };
    };
}

