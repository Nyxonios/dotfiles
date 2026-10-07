# NixOS live installer for Raspberry Pi 3 Model B
# Boot from USB, SSH in headlessly, install to SD card (mmcblk0)

{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # Some modules may not exist in downstream kernel images
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # Skip image compression for faster builds & easier flashing
  sdImage.compressImage = false;

  networking.hostName = "huginn-installer";

  # Headless access — SSH key login only, no passwords
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  users.users.nyxonios = {
    isNormalUser = true;
    description = "nyxonios";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGCcVvepMG+ixMGmxEO0hh3blHKvrwIBoDIpVgHDl03I martinseller@live.com"
    ];
  };

  # Allow passwordless sudo in the installer for convenience
  security.sudo.wheelNeedsPassword = false;

  # Zsh for the installer too
  programs.zsh.enable = true;

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = "aarch64-linux";
}
