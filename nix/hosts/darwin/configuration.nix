{ config, inputs, pkgs, ... }:
let
  inherit (import ./../../vars.nix { inherit pkgs; }) userData;
in
{
  users.users."${userData.user}".home = userData.homeDir;
  nixpkgs.config.allowUnfree = true;


  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [
      pkgs.aerospace
      pkgs.mkalias
    ];

  nix.nixPath = [
    "nixpkgs=${inputs.nixpkgs}"
  ];

  homebrew = {
    enable = true;

    casks = [
    ];

    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

  fonts.packages = [
    (pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];



  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = "/Applications";
      };
    in
    pkgs.lib.mkForce ''
      # Set up applications.
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

  system.defaults = {
    dock.autohide = true;

    finder.FXPreferredViewStyle = "clmv";
    LaunchServices.LSQuarantine = false;

    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleInterfaceStyle = "Dark";
      NSAutomaticWindowAnimationsEnabled = false;
      _HIHideMenuBar = true;
      KeyRepeat = 2;
      NSWindowShouldDragOnGesture = true;
    };
  };

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
