# Terminal Emulators
# Ghostty for all desktop systems
# - Linux: installed via nixpkgs
# - Darwin: installed via Homebrew cask
# Not installed on VMs

{ config, pkgs, lib, host, customLib, ... }:

let
  isDesktop = customLib.isDesktop (host.formFactor or "");
  isLinux = host.platform != "darwin";

  # Main Ghostty config
  ghosttyConfig = ''
    font-size = 9
    theme = catppuccin-mocha
    macos-titlebar-style = hidden
    confirm-close-surface = false
    app-notifications = no-clipboard-copy
    font-feature = -calt
    font-feature = -liga
    font-feature = -dlig

    # Load Linux-specific config if present
    config-file = ?linux-config
  '';

  # Catppuccin Mocha theme
  catppuccinMochaTheme = ''
    background = #1e1e2e
    foreground = #cdd6f4
    cursor-color = #f5e0dc
    cursor-text = #1e1e2e
    selection-background = #353b55
    selection-foreground = #cdd6f4

    # Black
    palette = 0=#45475a
    palette = 8=#585b70

    # Red
    palette = 1=#f38ba8
    palette = 9=#f38ba8

    # Green
    palette = 2=#a6e3a1
    palette = 10=#a6e3a1

    # Yellow
    palette = 3=#f9e2af
    palette = 11=#f9e2af

    # Blue
    palette = 4=#89b4fa
    palette = 12=#89b4fa

    # Magenta
    palette = 5=#f5c2e7
    palette = 13=#f5c2e7

    # Cyan
    palette = 6=#94e2d5
    palette = 14=#94e2d5

    # White
    palette = 7=#bac2de
    palette = 15=#a6adc8
  '';

  # Linux-specific Ghostty config
  ghosttyLinuxConfig = ''
    # Linux-specific Ghostty settings
    # This file is only loaded on Linux systems (via conditional config)

    # Disable clipboard copy notifications (Linux/GTK only)
    app-notifications = no-clipboard-copy
  '';
in
{
  config = lib.mkIf isDesktop (lib.mkMerge [
    # Linux: Install ghostty from nixpkgs
    (lib.mkIf isLinux {
      home.packages = [ pkgs.ghostty ];
    })
    # All platforms: Ghostty main config
    {
      xdg.configFile."ghostty/config".text = ghosttyConfig;
    }
    # All platforms: Ghostty theme
    {
      xdg.configFile."ghostty/themes/catppuccin-mocha".text = catppuccinMochaTheme;
    }
    # Linux: Generate Linux-specific config file
    (lib.mkIf isLinux {
      xdg.configFile."ghostty/linux-config".text = ghosttyLinuxConfig;
    })
  ]);
}
