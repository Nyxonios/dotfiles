# Hardware Mixins
# Self-gating modules for hardware-specific configurations

{ ... }:

{
  imports = [
    ./nvidia.nix
    ./bluetooth.nix
    ./audio.nix
  ];
}
