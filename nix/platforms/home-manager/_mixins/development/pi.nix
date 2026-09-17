# Pi Configuration
# Pi coding agent setup with evroc provider

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  pi = pkgs.callPackage ../../../../pkgs/pi { };
in
{
  config = {
    home.packages = [ pi ];

    home.file.".pi".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/pi";
  };
}
