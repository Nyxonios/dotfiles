# FZF Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      tmux.enableShellIntegration = true;
    };
  };
}
