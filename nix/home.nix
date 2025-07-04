{ config, pkgs, lib, inputs, ... }:
let
  inherit (import ./vars.nix { inherit pkgs; }) userData;
  inherit (config.lib.file) mkOutOfStoreSymlink;

  zig = inputs.zig-overlay.packages.${userData.platform}.master;
  zls = inputs.zls-overlay.packages.${userData.platform}.zls.overrideAttrs (old: { nativeBuildInputs = [ zig ]; });
in
{
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
    # Terminals
    pkgs.alacritty

    # Editors
    pkgs.neovim

    # Tools
    pkgs.kubectl
    pkgs.lazygit
    pkgs.air
    pkgs.k9s
    pkgs.ripgrep
    pkgs.btop
    pkgs.jq

    # Development stuff
    pkgs.cloc
    pkgs.sqlite
    pkgs.limbo
    pkgs.git-lfs
    pkgs.vault

    # Languages / Language servers / formatters
    pkgs.go
    pkgs.delve
    pkgs.gopls
    pkgs.gofumpt
    pkgs.nixd
    pkgs.nixpkgs-fmt
    zig
    zls

    # For LazyVim experiment
    pkgs.fd
    pkgs.lua51Packages.lua
    pkgs.lua51Packages.luarocks

    pkgs.lua-language-server
    pkgs.stylua
    pkgs.rustup

    pkgs.minio-warp
    pkgs.graphviz
    pkgs.awscli2
    pkgs.s3cmd

    # Shell scripts
    (import ./scripts/tmux-sessionizer.nix { inherit pkgs; })
    (import ./scripts/notes.nix { inherit pkgs; })
  ];



  # Programs that I use, where I want the configuration
  # files to live outside of Nix configurations.
  xdg.configFile.nvim.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/nvim;
  xdg.configFile.ghostty.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/ghostty;
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
    mkdir -p ~/docs
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
