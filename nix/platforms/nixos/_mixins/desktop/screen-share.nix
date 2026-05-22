# Wayland Screen Sharing
# Self-gating: Only activates on NixOS desktop systems running Hyprland
#
# xdg-desktop-portal-hyprland is automatically configured by the
# programs.hyprland module (imported in hyprland.nix). However, we need
# to explicitly configure the portal backend preference so that
# xdg-desktop-portal routes screen sharing requests to the Hyprland
# backend rather than falling back to a non-running GNOME backend.

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
  enableScreenShare = isDesktop && isNixOS;
  hyprlandEnabled = config.programs.hyprland.enable or false;
in
{
  config = lib.mkIf (enableScreenShare && hyprlandEnabled) {
    xdg.portal.config = {
      Hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };
}
