# NixOS Desktop Configuration
# This file contains only hardware-specific settings
# All generic NixOS behavior is defined in self-gating modules

{ config, pkgs, lib, host, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

}
