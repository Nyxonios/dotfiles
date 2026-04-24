# Opencode Configuration
# Only enabled on NixOS machines

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = customLib.mkIfPlatform "nixos"
    {
      home.packages = [ pkgs.opencode ];
    }
    host;
  xdg.configFile.opencode.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/opencode";
}
