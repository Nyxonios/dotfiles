# NetworkManager
# Applies to all NixOS systems

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    networking.networkmanager.enable = true;
  };
}
