# System Mixins for macOS
# Core system settings

{ ... }:

{
  imports = [
    ./fonts.nix
    ./nix.nix
    ./system-settings.nix
  ];
}
