# NixOS SD image for Raspberry Pi 3 Model B
# Same settings as huginn but without nixos-hardware (sd-image-aarch64.nix handles U-Boot)

{ config, pkgs, lib, inputs, modulesPath, ... }:

{
  imports = [
    ./hardware-configuration.nix
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # Reduce write pressure on the SD card
  boot.tmp.cleanOnBoot = true;
  services.journald.settings = {
    Journal = {
      SystemMaxUse = "100M";
      RuntimeMaxUse = "50M";
    };
  };

  # Headless: no need for full NixOS docs or man caches
  documentation.nixos.enable = false;
  documentation.man.cache.enable = false;

  # Console + SSH access for nyxonios
  users.users.nyxonios = {
    isNormalUser = true;
    description = "nyxonios";
    group = "nyxonios";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    initialHashedPassword = "$6$GAtYTL9CAMBBE.Vo$6oNnWjQQUGaDQDHK7f2YJO8Pqacf1j09bb8.kz9V/z1w92btXvCB2Ve.cMGqG4mP5FON4txQO7SU8IaIbA.SX.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCcVvepMG+ixMGmxEO0hh3blHKvrwIBoDIpVgHDl03I martinseller@live.com"
    ];
  };
  users.groups.nyxonios = {};

  # Passwordless sudo for headless convenience
  security.sudo.wheelNeedsPassword = false;

  # Allow nyxonios to receive store paths from the desktop (nix copy, nixos-rebuild --target-host)
  nix.settings.trusted-users = [ "root" "nyxonios" ];

  # Allow sudo over SSH without a TTY (required for --target-host activation)
  security.sudo.extraConfig = ''
    Defaults !requiretty
  '';

  programs.zsh.enable = true;

  # OpenSSH for remote access
  services.openssh.enable = true;

  # WiFi/network diagnostic tools for headless debugging
  environment.systemPackages = with pkgs; [
    iw                 # WiFi phy info and manual scanning
    wpa_supplicant     # manual wpa_cli if NM fails
    usbutils           # lsusb for USB devices
    ethtool            # interface diagnostics
    pciutils           # lspci for PCI/SDIO devices
    curl               # fetch files if needed
    dhcpcd             # standalone DHCP client fallback
  ];

  # Enable WiFi firmware and NetworkManager for headless wireless
  # CRITICAL: must set enableRedistributableFirmware=false to avoid
  # conflicts between firmwareLinuxNonfree and raspberrypiWirelessFirmware
  # (see https://github.com/NixOS/nixpkgs/issues/115652, NixOS Discourse #17576)
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [ pkgs.raspberrypiWirelessFirmware ];
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  # 1 GB swapfile to avoid OOM during activation or light builds
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 1024;
  }];

  # Skip image compression for easier flashing
  sdImage.compressImage = false;
}
