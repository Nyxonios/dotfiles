# GNOME Desktop
# Self-gating: Only activates on desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
in
{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && isNixOS) {
    # Enable GNOME
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # XDG portals for Wayland
    xdg.portal = {
      enable = true;
      config.default = {
        common = [ "gnome" ];
      };
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      configPackages = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
    };
  };
}
