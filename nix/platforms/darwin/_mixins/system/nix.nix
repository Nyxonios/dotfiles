# Nix Settings for macOS
# Platform-specific GC timing (interval format for launchd)

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "darwin") {
    nix.gc.interval = [
      {
        Hour = 3;
        Minute = 15;
        Weekday = 7;
      }
    ];
  };
}
