# Aerospace Window Manager
# Self-gating: Only activates on Darwin desktop systems

{ config, lib, host, pkgs, customLib, ... }:

{
  config = customLib.mkIfDarwinDesktop {
    # Install Aerospace window manager
    environment.systemPackages = [ pkgs.aerospace ];
  } host;
}
