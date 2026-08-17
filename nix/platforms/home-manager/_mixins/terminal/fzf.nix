# FZF Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = false;
      tmux.enableShellIntegration = true;
    };
  };
}
