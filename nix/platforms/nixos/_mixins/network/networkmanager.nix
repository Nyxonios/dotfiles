# NetworkManager
# Applies to all NixOS systems

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "nixos" {
    networking.networkmanager.enable = true;
  } host;
}
