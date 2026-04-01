# Browser Configuration
# Platform-specific browser setup

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    # Install Brave browser on NixOS
    home.packages = [
      pkgs.firefox
    ];
  };
}
