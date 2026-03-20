# GNOME Desktop
# Self-gating: Only activates on desktop systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
  isNixOS = host.platform == "nixos";
in
{
  config = lib.mkIf (isDesktop && isNixOS) {
    # Enable GNOME
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # XDG portals for Wayland
    xdg.portal = {
      enable = true;
      config.default = {
        common = [ "gnome" ];
      };
      extraPortals = with config.nixpkgs.pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      configPackages = with config.nixpkgs.pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
    };
  };
}
