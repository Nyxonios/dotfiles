# K9S Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [ pkgs.zeroclaw ];

    # Configure zeroclaw to use XDG config directory
    home.sessionVariables = {
      ZEROCLAW_CONFIG_DIR = "${config.xdg.configHome}/zeroclaw";
    };

    xdg.configFile.zeroclaw.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/zeroclaw";
  };
}
