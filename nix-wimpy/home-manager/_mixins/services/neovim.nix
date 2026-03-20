# Neovim Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    # Symlink nvim config from dotfiles
    xdg.configFile.nvim.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/nvim";
  };
}
