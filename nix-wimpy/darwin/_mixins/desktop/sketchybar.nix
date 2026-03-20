# SketchyBar
# Self-gating: Only activates on darwin desktop systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
  isDarwin = host.platform == "darwin";
in
{
  config = lib.mkIf (isDesktop && isDarwin) {
    # SketchyBar is installed via nixpkgs in the host configuration
    # Additional system-level configuration can go here
  };
}
