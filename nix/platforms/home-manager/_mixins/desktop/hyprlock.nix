# Hyprlock / Hypridle Configuration
# Screen locker and idle daemon for Hyprland

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    home.packages = [ pkgs.hyprlock pkgs.hypridle ];
  };
}
