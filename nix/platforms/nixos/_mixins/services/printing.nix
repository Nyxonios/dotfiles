# Printing (CUPS)
# Applies to desktop NixOS systems

{ config, lib, host, customLib, ... }:

{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && host.platform == "nixos") {
    services.printing.enable = true;
  };
}
