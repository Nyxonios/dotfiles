# Homebrew Default Configuration
# Applies to all Darwin systems

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "darwin") {
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
  };
}
