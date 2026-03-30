# Nix Settings for NixOS
# Platform-specific GC timing (dates format for systemd)

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "nixos" {
    nix = {
      gc.dates = "weekly";
      optimise.automatic = true;
    };
  } host;
}
