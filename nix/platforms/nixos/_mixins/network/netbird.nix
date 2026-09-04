{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop
    {
      services.netbird.enable = true;

      environment.systemPackages = with pkgs; [
        netbird
      ];
    }
    host;
}
