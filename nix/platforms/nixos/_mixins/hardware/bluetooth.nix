# Bluetooth Configuration
# Applies to all desktop NixOS systems

{ config, lib, host, customLib, ... }:

{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && host.platform == "nixos") {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
