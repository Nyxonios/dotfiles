{ inputs, pkgs, userData, ... }:
{
  users.users."${userData.user}".home = userData.homeDir;
  system.primaryUser = "${userData.user}";
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


  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
  ];

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
  ];


  nix.settings.experimental-features = "nix-command flakes";
}
