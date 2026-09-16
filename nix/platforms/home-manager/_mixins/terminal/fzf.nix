# FZF Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = false;
      # Disable fzf-tmux script integration; use inline fzf instead.
      # The fzf-tmux split-pane mode has a bug where selected history items
      # are not returned to the zsh buffer, leaving the prompt empty.
      tmux.enableShellIntegration = false;
    };
  };
}
