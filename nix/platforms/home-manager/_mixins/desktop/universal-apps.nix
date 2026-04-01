# Universal Desktop Applications
# Cross-platform apps that work on all desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf isDesktop {
    home.packages = [
      # Productivity
      pkgs.obsidian

      # Communication
      pkgs.telegram-desktop

      # Media
      pkgs.spotify
    ];
  };
}
