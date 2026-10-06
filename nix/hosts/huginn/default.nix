# NixOS Configuration for Raspberry Pi 3 Model B
# Very bare-bones, terminal-only headless SBC

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-3
    ./hardware-configuration.nix
  ];

  # Reduce write pressure on the SD card
  boot.tmp.cleanOnBoot = true;
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';

  # Headless: no need for full NixOS docs or man caches
  documentation.nixos.enable = false;
  documentation.man.generateCaches = false;
}
