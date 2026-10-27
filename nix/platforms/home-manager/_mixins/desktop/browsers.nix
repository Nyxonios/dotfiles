# Browser Configuration
# Platform-specific browser setup

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDarwin = host.platform == "darwin";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf ((isNixOS || isDarwin) && isDesktop) {
    # Install Firefox on NixOS and Darwin
    home.packages = [
      pkgs.firefox
    ];
  };
}
