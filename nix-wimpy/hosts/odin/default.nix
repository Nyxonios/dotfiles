# NixOS Desktop Configuration
# This file contains only hardware-specific settings
# All behavior is defined in self-gating modules

{ config, pkgs, lib, host, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname
  networking.hostName = "nixos-desktop";

  # Platform
  nixpkgs.hostPlatform = host.system;

  # Timezone
  time.timeZone = "Europe/Stockholm";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  # User account
  users.users.${host.username} = {
    isNormalUser = true;
    description = host.username;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  users.defaultUserShell = pkgs.zsh;

  # Enable experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };
  nix.optimise.automatic = true;

  # System state version
  system.stateVersion = "23.11";
}
