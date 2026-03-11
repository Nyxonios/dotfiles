# Machine Types Enum
# 
# This file defines the valid machine types for this Nix configuration.
# Each machine type determines which rebuild command and configuration
# is used for the system.
#
# To use this enum in your configuration:
#   1. Import this file where needed
#   2. Set the machineType in vars.nix using one of these values
#   3. The system will automatically configure itself based on the type
#
# Example in vars.nix:
#   machineType = machineTypes.Darwin;

{
  # macOS systems using nix-darwin
  # Use this for Mac computers where you're managing the system with nix-darwin
  # Rebuild command: sudo darwin-rebuild switch --flake ~/dotfiles/nix#work
  Darwin = "darwin";
  
  # NixOS systems
  # Use this for computers running NixOS (Linux distribution)
  # Rebuild command: sudo nixos-rebuild switch --flake ~/dotfiles/nix#<username>
  NixOS = "nixos";
  
  # Standalone Linux systems using home-manager
  # Use this for Linux machines (not NixOS) where you only manage user config
  # Rebuild command: nix run nixpkgs#home-manager -- switch --flake ~/dotfiles/nix#vm
  Linux = "linux";
}
