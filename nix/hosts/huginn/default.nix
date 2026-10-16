# Minimal huginn configuration — Raspberry Pi 3 Model B
# Bypasses the full builder chain (no desktop/gaming/home-manager bloat)
# Only essentials: SSH, neovim, WiFi tools, swap, user account

{ config, pkgs, lib, inputs, modulesPath, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Use standard cached kernel (nixos-hardware sets linux-rpi, override to avoid long build)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # SD card longevity
  boot.tmp.cleanOnBoot = true;
  services.journald.settings = {
    Journal = { SystemMaxUse = "100M"; RuntimeMaxUse = "50M"; };
  };

  # Timezone / locale (normally from platforms/common, now explicit)
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";

  # Headless — no docs / man caches
  documentation.nixos.enable = false;
  documentation.man.cache.enable = false;

  # Nix GC + optimise (normally from platforms/system/nix.nix)
  nix = {
    gc = { automatic = true; dates = "weekly"; persistent = true; };
    optimise.automatic = true;
  };

  # The firmware partition was already correctly written by sd-image-aarch64.nix
  # at image build time. Disable the activation script to avoid running out of
  # space on the 30 MB FAT partition when future rebuilds try to re-copy files.
  hardware.raspberry-pi.firmware = {
    enable = lib.mkForce false;
    uboot.enable = true;
  };

  # User account
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

  # Allow nyxonios to receive store paths from the desktop
  nix.settings.trusted-users = [ "root" "nyxonios" ];

  # Allow sudo over SSH without a TTY (required for --target-host activation)
  security.sudo.extraConfig = ''Defaults !requiretty'';

  programs.zsh.enable = true;

  # Minimal home-manager: only zsh config + btop (no desktop/development bloat)
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      host = { name = "huginn"; platform = "nixos"; system = "aarch64-linux"; username = "nyxonios"; home = "/home/nyxonios"; email = "mseller@evroc.com"; formFactor = "sbc"; gpu = []; tags = []; };
    };
    users.nyxonios = { config, pkgs, lib, host, ... }: {
      imports = [
        ../../platforms/home-manager/_mixins/terminal/zsh.nix
      ];
      home.packages = [ pkgs.btop ];
      home.stateVersion = "24.05";
      programs.home-manager.enable = true;
    };
  };

  # OpenSSH for remote access
  services.openssh.enable = true;

  # The ONE package requested: neovim. Plus minimal WiFi/network utilities.
  environment.systemPackages = with pkgs; [
    neovim
    neovim
    git
    iw
    wpa_supplicant
    dhcpcd
    curl
  ];

  # WiFi firmware — nixos-hardware's raspberry-pi-3 module provides its own
  # wireless firmware. Disable the generic redistributable firmware to avoid
  # file conflicts (NixOS Discourse #17576, nixpkgs#115652).
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # NetworkManager for WiFi. Use wpa_supplicant backend since iwd is not
  # always reliable on the Pi 3 Broadcom SDIO chip.
  networking.networkmanager = {
    enable = true;
    wifi.backend = "wpa_supplicant";
  };
  networking.wireless.enable = lib.mkForce false;

  # 1 GB swapfile
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 1024;
  }];
}
