# Hyprland Configuration
# Self-gating: Only applies to NixOS desktop/laptop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    # Window manager and desktop environment configs
    xdg.configFile.hypr.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/hypr";
  };
}
