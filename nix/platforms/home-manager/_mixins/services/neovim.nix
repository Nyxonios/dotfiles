# Neovim Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    # Note: Neovim config is managed manually in ~/dotfiles/.config/nvim
    # To use it, ensure the directory exists and contains your config
  };
}
