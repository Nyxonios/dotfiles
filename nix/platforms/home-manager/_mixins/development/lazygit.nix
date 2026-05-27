# Lazygit Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [ pkgs.lazygit ];
    xdg.configFile.lazygit.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/lazygit";
  };
}
