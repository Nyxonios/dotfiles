{ config, pkgs, lib, ... }:
let
  inherit (import ./vars.nix { inherit pkgs; }) userData;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = userData.user;
  home.homeDirectory = userData.homeDir;
  xdg.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Development stuff
    pkgs.neovim
    # pkgs.alacritty
    pkgs.lazygit
    pkgs.cloc
    pkgs.sqlite
    pkgs.limbo
    pkgs.air
    pkgs.k9s

    # Languages / Language servers / formatters
    pkgs.go
    pkgs.gopls
    pkgs.gofumpt
    pkgs.nixd
    pkgs.nixpkgs-fmt
    # pkgs.zigpkgs.master
    pkgs.zls
    pkgs.lua-language-server
    pkgs.stylua
    pkgs.ansible

    # System stuff
    pkgs.ripgrep
    pkgs.btop
    pkgs.jq

    # Development libs
  ];


  # Programs that I use, where I want the configuration
  # files to live outside of Nix configurations.
  xdg.configFile.nvim.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/nvim;
  xdg.configFile.alacritty.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/alacritty;
  xdg.configFile.k9s.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/k9s;

  programs = {
    fzf = import ./home/fzf.nix { inherit pkgs; };
    zsh = import ./home/zsh/zsh.nix { inherit config pkgs lib; };
    tmux = import ./home/tmux.nix { inherit config pkgs; };
  };

  # On fresh installs, we ensure that we have the "development" folder created.
  home.activation.setupDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ~/development 
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
