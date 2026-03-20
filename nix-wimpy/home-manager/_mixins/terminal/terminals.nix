# Terminal Emulators

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    home.packages = [
      pkgs.alacritty
    ]
    # Ghostty only on Linux (NixOS and home-manager)
    ++ lib.optionals (host.platform == "nixos" || host.platform == "home-manager") [
      pkgs.ghostty
    ];

    # Symlink terminal configs from dotfiles
    xdg.configFile.alacritty.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/alacritty";

    # Ghostty only on Linux
    xdg.configFile.ghostty = lib.mkIf (host.platform == "nixos" || host.platform == "home-manager") {
      source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty";
    };
  };
}
