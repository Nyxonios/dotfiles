# Services Mixins for Home Manager
# User services and background processes

{ ... }:

{
  imports = [
    ./neovim.nix
    ./rofi.nix
    ./hypr.nix
    ./applications.nix
    ./wleave.nix
  ];
}
