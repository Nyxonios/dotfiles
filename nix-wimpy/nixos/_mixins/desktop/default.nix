# Desktop Environment Mixins
# Self-gating modules for desktop configurations

{ ... }:

{
  imports = [
    ./gnome.nix
    ./hyprland.nix
    ./fonts.nix
  ];
}
