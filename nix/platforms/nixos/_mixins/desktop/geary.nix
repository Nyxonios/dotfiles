
{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop {
    environment.systemPackages = with pkgs; [
      geary
    ];
  } host;
}
