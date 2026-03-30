# Printing (CUPS)
# Applies to desktop NixOS systems

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop {
    services.printing.enable = true;
  } host;
}
