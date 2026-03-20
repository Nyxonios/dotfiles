# Nix Settings for NixOS
# Platform-specific GC timing (dates format for systemd)

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    nix = {
      gc.dates = "weekly";
      optimise.automatic = true;
    };
  };
}
