# Nix Settings for macOS
# Platform-specific GC timing (interval format for launchd)

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "darwin" {
    nix = {
      gc = {
        automatic = true;
        interval = [
          {
            Hour = 3;
            Minute = 15;
            Weekday = 7;
          }
        ];
      };
      optimise.automatic = true;
    };
  } host;
}
