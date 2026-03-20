# Printing (CUPS)
# Applies to desktop NixOS systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
in
{
  config = lib.mkIf (isDesktop && host.platform == "nixos") {
    services.printing.enable = true;
  };
}
