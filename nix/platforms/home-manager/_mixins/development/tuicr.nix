# tuicr Configuration
# tuicr MR/PR review in the terminal

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [ pkgs.tuicr ];
    xdg.configFile.tuicr.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/tuicr";
  };
}
