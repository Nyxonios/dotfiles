# Aerospace Window Manager
# Self-gating: Only activates on darwin desktop systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
  isDarwin = host.platform == "darwin";
in
{
  config = lib.mkIf (isDesktop && isDarwin) {
    # Aerospace is installed via homebrew in the host configuration
    # This mixin could add system-level aerospace configuration
  };
}
