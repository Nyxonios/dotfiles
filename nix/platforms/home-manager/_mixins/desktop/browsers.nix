# Browser Configuration
# Platform-specific browser setup

{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop {
    # Install Brave browser on NixOS
    home.packages = [
      pkgs.brave
      pkgs.firefox
    ];
  } host;
}
