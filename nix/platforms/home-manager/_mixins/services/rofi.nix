# Rofi Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    # Symlink the entire rofi config directory from dotfiles
    xdg.configFile.rofi.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/rofi";
  };
}
