# Bluetooth Configuration
# Applies to all desktop NixOS systems

{ config, lib, host, customLib, pkgs, ... }:

{
  config = customLib.mkIfNixOSDesktop {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.AutoEnable = "true";
    };

    environment.systemPackages = with pkgs; [ blueman ];
  } host;
}
