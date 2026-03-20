# macOS System Defaults
# Self-gating: Applies to all Darwin desktop systems

{ config, lib, host, ... }:

let
  isDarwin = host.platform == "darwin";
  isDesktop = host.desktop or false;
in
{
  config = lib.mkIf (isDarwin && isDesktop) {
    # macOS-specific defaults
    system.defaults = {
      dock = {
        autohide = true;
        show-recents = false;
      };

      finder.FXPreferredViewStyle = "clmv";
      LaunchServices.LSQuarantine = false;

      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleInterfaceStyle = "Dark";
        NSAutomaticWindowAnimationsEnabled = false;
        _HIHideMenuBar = true;
        KeyRepeat = 1;
        NSWindowShouldDragOnGesture = true;
        "com.apple.swipescrolldirection" = false;
      };
    };
  };
}
