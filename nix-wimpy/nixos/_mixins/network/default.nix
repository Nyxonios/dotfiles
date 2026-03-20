# Network Mixins
# Self-gating modules for network configuration

{ ... }:

{
  imports = [
    ./networkmanager.nix
    ./ssh.nix
  ];
}
