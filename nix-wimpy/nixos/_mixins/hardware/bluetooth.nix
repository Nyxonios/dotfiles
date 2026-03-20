# Bluetooth Configuration
# Applies to all desktop NixOS systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
in
{
  config = lib.mkIf (isDesktop && host.platform == "nixos") {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
