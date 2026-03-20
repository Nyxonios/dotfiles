# macOS Work Configuration
# This file contains only work-specific settings
# All generic Darwin behavior is defined in self-gating modules

{ config, pkgs, lib, host, ... }:

{
  # Work-specific system packages
  # Note: User applications like obsidian, spotify are managed by Home Manager
  environment.systemPackages = [
    pkgs.nodejs_20
    pkgs.pnpm_8
    pkgs.typescript
    pkgs.prettierd
  ];
}
