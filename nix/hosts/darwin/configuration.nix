{ config, inputs, pkgs, ... }:
let
  inherit (import ./../../vars.nix { inherit pkgs; }) userData;
in
{
  imports = [
    ./../shared.nix
  ];

  environment.systemPackages = [
    pkgs.aerospace
    pkgs.sketchybar
    pkgs.obsidian
    pkgs.mkalias

    pkgs.nodejs_20
    pkgs.pnpm_8
    pkgs.typescript
    pkgs.prettierd
  ];

  # We define the platform specific hm stuff here, so the 
  # home.nix file can be shared between all platforms.
  home-manager.users."${userData.user}" = { config, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile.aerospace.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/aerospace;
      xdg.configFile.karabiner.source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/karabiner;
    };


  homebrew = {
    enable = true;

    brews = [
      "zls"
    ];

    casks = [
      "betterdisplay"
      "spotify"
      "raycast"
      "ghostty"
    ];

    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };


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

  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;
}
