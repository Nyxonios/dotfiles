# System Mixins for NixOS
# Core system settings

{ ... }:

{
  imports = [
    ./common.nix
    ./nix.nix
  ];
}
