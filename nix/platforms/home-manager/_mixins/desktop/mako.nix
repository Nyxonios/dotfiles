# Mako Notification Daemon
# Self-gating: Only activates on desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  # Catppuccin Mocha palette
  palette = {
    base = "1e1e2e";
    mantle = "181825";
    surface0 = "313244";
    surface1 = "45475a";
    surface2 = "585b70";
    text = "cdd6f4";
    rosewater = "f5e0dc";
    lavender = "b4befe";
    red = "f38ba8";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    blue = "89b4fa";
    mauve = "cba6f7";
    flamingo = "f2cdcd";
  };
in
{
  config = customLib.mkIfNixOSDesktop {
    services.mako = {
      enable = true;

      settings = {
        # Appearance - Catppuccin Mocha theme
        background-color = "#${palette.base}";
        text-color = "#${palette.text}";
        border-color = "#${palette.blue}";
        border-size = 2;
        border-radius = 10;
        padding = "10";
        margin = "10";

        # Font
        font = "monospace 12";

        # Icon settings
        icons = true;
        icon-path = "${pkgs.papirus-icon-theme}/share/icons/Papirus";

        # Timeout
        default-timeout = 5000;
        ignore-timeout = false;

        # Layout
        width = 350;
        height = 150;
        layer = "overlay";
        anchor = "top-right";
      };

      # Extra options for progress and actions
      extraConfig = ''
        [urgency=low]
        border-color=#${palette.surface1}
        default-timeout=3000

        [urgency=normal]
        border-color=#${palette.blue}
        default-timeout=5000

        [urgency=high]
        border-color=#${palette.red}
        default-timeout=0
        background-color=#${palette.mantle}
      '';
    };
  } host;
}
