# Browser Configuration
# Platform-specific browser setup

{ config, pkgs, lib, host, ... }:

let
  isDesktop = host.desktop or false;
  isNixOS = host.platform == "nixos";
in
{
  config = lib.mkIf (isDesktop && isNixOS) {
    # Install Brave browser on NixOS
    home.packages = [
      pkgs.brave
    ];
  };
}
