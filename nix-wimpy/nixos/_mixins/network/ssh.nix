# SSH Configuration
# Applies to all NixOS systems

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = true;
      };
    };
  };
}
