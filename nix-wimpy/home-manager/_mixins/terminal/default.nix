# Terminal Mixins
# Shell, terminal emulators, and terminal tools

{ ... }:

{
  imports = [
    ./zsh.nix
    ./tmux.nix
    ./fzf.nix
    ./terminals.nix
  ];
}
