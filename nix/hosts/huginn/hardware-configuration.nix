# Hardware configuration for Raspberry Pi 3 Model B
# Tailored to the generic AArch64 NixOS SD card image

{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usbhid"
    "usb_storage"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Raspberry Pi 3 boots via U-Boot + extlinux, not GRUB or systemd-boot
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Root filesystem as laid out by the generic AArch64 SD image
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  # FAT firmware partition from the SD image
  # Mounting this allows nixos-rebuild to update config.txt / U-Boot
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Required for Wi-Fi / Bluetooth firmware on Pi 3
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Enable declarative firmware partition management
  hardware.raspberry-pi.firmware = {
    enable = true;
    uboot.enable = true;
  };
}
