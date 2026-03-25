# Neovim Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = {
    # Install neovim but don't manage config via programs.neovim
    home.packages = [ pkgs.neovim ];
    
    # Set as default editor
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    
    # Symlink the entire nvim config directory from dotfiles
    xdg.configFile.nvim.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/nvim";
  };
}
