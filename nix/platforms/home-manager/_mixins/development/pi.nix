# Pi Configuration
# Pi coding agent setup with evroc provider

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [ pkgs.pi ];

    home.file.".pi".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/pi";
  };
}
