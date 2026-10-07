# NixOS Desktop Configuration
# This file contains only hardware-specific settings
# All generic NixOS behavior is defined in self-gating modules

{ config, pkgs, lib, host, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Enable cross-compilation (emulation) for Raspberry Pi aarch64 builds
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

}
