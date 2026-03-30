# GNOME Desktop
# Self-gating: Only activates on NixOS desktop systems

{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop {
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
  } host;
}
