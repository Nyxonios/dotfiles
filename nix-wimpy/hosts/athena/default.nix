# macOS Work Configuration
# This file contains only hardware-specific settings
# All behavior is defined in self-gating modules

{ config, pkgs, lib, host, ... }:

{
  imports = [ ];

  # System configuration
  nixpkgs.hostPlatform = host.system;
  system.stateVersion = 5;

  # Set primary user
  system.primaryUser = host.username;
  users.users.${host.username}.home = host.home;

  # Git commit hash for darwin-version
  system.configurationRevision = config.self.rev or config.self.dirtyRev or null;

  # Homebrew configuration
  homebrew = {
    enable = true;

    brews = [
      "zls"
    ];

    casks = [
      "betterdisplay"
      "raycast"
      "ghostty"
      # Note: spotify is installed via Home Manager (shared across platforms)
    ];

    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

  # System packages (work-specific)
  # Note: User applications like obsidian, spotify are managed by Home Manager
  environment.systemPackages = [
    pkgs.aerospace
    pkgs.sketchybar
    pkgs.mkalias

    pkgs.nodejs_20
    pkgs.pnpm_8
    pkgs.typescript
    pkgs.prettierd
  ];

  # Nix settings
  nix.gc = {
    automatic = true;
    interval = [
      {
        Hour = 3;
        Minute = 15;
        Weekday = 7;
      }
    ];
  };

  nix.settings.experimental-features = "nix-command flakes";
}
