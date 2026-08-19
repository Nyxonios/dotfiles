# Bluetooth Configuration
# Applies to all desktop NixOS systems

{ config, lib, host, customLib, pkgs, ... }:

{
  config = customLib.mkIfNixOSDesktop {
    # Load Bluetooth and HID kernel modules
    boot.kernelModules = [ "btusb" "hid_generic" ];

    # Disable USB autosuspend for HID devices to prevent wireless receiver sleep
    boot.kernelParams = [ "usbcore.autosuspend=-1" ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        AutoEnable = "true";
        Privacy = "device";
        JustWorksRepairing = "always";
        # CRITICAL: Disable userspace HID to fix BLE keyboard input
        # (BlueZ intercepts keyboard events but often fails silently)
        UserspaceHID = false;
      };
    };

    services.blueman.enable = true;
    environment.systemPackages = with pkgs; [ blueman ];
  } host;
}
