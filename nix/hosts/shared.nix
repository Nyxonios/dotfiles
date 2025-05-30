{ inputs, pkgs, ... }:
let
  inherit (import ./../vars.nix { inherit pkgs; }) userData;
in
{
  nix.gc = {
    automatic = true;
    interval = [
      {
        Hour = 3;
        Minute = 15;
        Weekday = 7;
      }
    ];
  };

  users.users."${userData.user}".home = userData.homeDir;

  environment.systemPackages =
    [
      pkgs.mkalias
      pkgs.btop
    ];

  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
  ];

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
  ];


  nix.settings.experimental-features = "nix-command flakes";

  nixpkgs.hostPlatform = "${userData.platform}";
}
