# Homebrew Default Configuration
# Applies to all Darwin systems

{ config, lib, host, customLib, ... }:

{
  config = customLib.mkIfPlatform "darwin" {
    homebrew = {
      enable = true;

      casks = [
        "betterdisplay"
        "ghostty"
        "mattermost"
        "raycast"
      ];

      onActivation = {
        cleanup = "zap";
        autoUpdate = true;
        upgrade = true;
      };
    };
  } host;
}
