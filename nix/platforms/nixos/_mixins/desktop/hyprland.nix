# Hyprland Window Manager
# Self-gating: Only activates on NixOS desktop systems

{ config, pkgs, lib, host, inputs, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
  enableHyprland = isDesktop && isNixOS;
in
{
  imports = lib.optionals enableHyprland [
    inputs.hyprland.nixosModules.default
  ];

  config = customLib.mkIfNixOSDesktop {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Required for hyprlock to authenticate
    security.pam.services.hyprlock = {};

    # Portal configuration for screen sharing
    # Hyprland automatically registers xdg-desktop-portal-hyprland,
    # but we need to explicitly set the backend preference so that
    # xdg-desktop-portal routes screen sharing to the Hyprland portal
    # rather than falling back to a non-running GNOME backend.
    xdg.portal = {
      config.Hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };

    # Environment variables for Wayland/NVIDIA
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_SESSION_TYPE = "wayland";
      CLUTTER_BACKEND = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    };

    # System packages for Hyprland
    environment.systemPackages = with pkgs; [
      hyprcursor
      awww
      rofi
    ];
  } host;
}
