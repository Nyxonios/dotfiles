# Browser Configuration
# Platform-specific browser setup

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
in
{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && isNixOS) {
    # Install Brave browser on NixOS
    home.packages = [
      pkgs.brave
      pkgs.firefox
    ];
  };
}
