# Neovim Configuration

{ config, pkgs, lib, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  pkl-grammar = pkgs.tree-sitter-grammars.tree-sitter-pkl;
in
{
  config = {
    # Install neovim but don't manage config via programs.neovim
    home.packages = [
      pkgs.tree-sitter
      pkgs.neovim
    ];

    # Pre-install the pkl treesitter parser via nix
    home.file.".local/share/nvim/site/parser/pkl.so".source = "${pkl-grammar}/parser";
    home.file.".local/share/nvim/site/queries/pkl".source = "${pkl-grammar}/queries";

    # Set as default editor
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # Symlink the entire nvim config directory from dotfiles
    xdg.configFile.nvim.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/nvim";
  };
}
