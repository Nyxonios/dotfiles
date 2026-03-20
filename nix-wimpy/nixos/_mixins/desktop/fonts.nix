# Font Configuration
# Applies to all systems

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    fonts = {
      packages = with config.nixpkgs.pkgs; [
        nerd-fonts.fira-code
      ];
    };
  };
}
