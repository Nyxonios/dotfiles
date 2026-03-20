# Aerospace Window Manager
# Self-gating: Only activates on darwin desktop systems

{ config, lib, host, pkgs, customLib, ... }:

let
  isDarwin = host.platform == "darwin";
in
{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && isDarwin) {
    # Install Aerospace window manager
    environment.systemPackages = [ pkgs.aerospace ];
  };
}
