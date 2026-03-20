# Font Configuration for macOS
# Applies to all darwin systems

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "darwin") {
    fonts = {
      packages = with config.nixpkgs.pkgs; [
        nerd-fonts.fira-code
      ];
    };
  };
}
