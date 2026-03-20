# Terminal Emulators
# Ghostty for all desktop systems (Darwin, NixOS, Home Manager)
# Not installed on VMs

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf isDesktop {
    home.packages = [
      pkgs.ghostty
    ];

    # Symlink ghostty config from dotfiles
    xdg.configFile.ghostty.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty";
  };
}
