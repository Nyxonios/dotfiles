# Nix-managed macOS Desktop Applications
# Apps installed via Nix instead of Homebrew to avoid cask metadata bugs

{ config, pkgs, lib, host, customLib, ... }:

let
  isDarwin = host.platform == "darwin";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isDarwin && isDesktop) {
    # Add BetterDisplay to system packages so it's available
    environment.systemPackages = [ pkgs.betterdisplay ];

    # Symlink BetterDisplay to /Applications so it's discoverable by LaunchServices
    system.activationScripts.postUserActivation.text = ''
      echo "Linking BetterDisplay to /Applications..."
      rm -f "/Applications/BetterDisplay.app"
      ln -sf "${pkgs.betterdisplay}/Applications/BetterDisplay.app" "/Applications/BetterDisplay.app"
    '';
  };
}
