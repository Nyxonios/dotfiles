# K9S Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [ pkgs.k9s ];
    xdg.configFile.k9s.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/k9s";
  };
}
