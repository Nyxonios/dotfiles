# SSH Configuration
# Applies to all NixOS systems

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "nixos" {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = true;
      };
    };
  } host;
}
