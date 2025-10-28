{ config, pkgs, lib, inputs, ... }:
let
  inherit (import ./vars.nix { inherit pkgs; }) userData;
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.username = userData.user;
  home.homeDirectory = userData.homeDir;
  xdg.enable = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    # Terminals
    pkgs.alacritty

    # Editors
    pkgs.neovim

    # Tools
    pkgs.git
    pkgs.kubectl
    pkgs.lazygit
    pkgs.k9s
    pkgs.ripgrep
    pkgs.btop
    pkgs.jq
    pkgs.gnumake42
    pkgs.btop

    # Development stuff
    pkgs.cloc
    pkgs.sqlite
    pkgs.git-lfs
    pkgs.vault
    pkgs.clang-tools

    # Languages / Language servers / formatters
    pkgs.go
    pkgs.delve
    pkgs.gopls
    pkgs.gofumpt
    pkgs.nixd
    pkgs.nixpkgs-fmt
    pkgs.zig
    pkgs.zls
    pkgs.shellcheck
    pkgs.bash-language-server
    pkgs.ols
    pkgs.odin
    pkgs.lua-language-server
    pkgs.stylua
    pkgs.ansible
    pkgs.rustup

    pkgs.minio-warp
    pkgs.graphviz
    pkgs.awscli2
    pkgs.s3cmd

    # Tools
    pkgs.obsidian

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
    direnv = import ./home/direnv.nix;
  };

  # On fresh installs, we ensure that we have the "development" folder created.
  home.activation.setupDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ~/development 
    mkdir -p ~/docs
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

}
