# Nix Settings for NixOS
# Platform-specific GC timing (dates format for systemd)

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "nixos" {
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        persistent = true;
      };
      optimise.automatic = true;
    };
  } host;
}
