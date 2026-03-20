# Nix Settings for macOS
# Applies to all darwin systems

{ config, lib, host, inputs, ... }:

{
  config = lib.mkIf (host.platform == "darwin") {
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

      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      settings.experimental-features = "nix-command flakes";
    };
  };
}
