# Screenshot Utilities
# grim + slurp + wl-clipboard for Wayland screenshot selection
# Self-gating: Only activates on NixOS desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");

  screenshot-region = pkgs.writeShellApplication {
    name = "screenshot-region";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard ];
    text = ''
      grim -g "$(slurp)" - | wl-copy -t image/png
    '';
  };

  screenshot-full = pkgs.writeShellApplication {
    name = "screenshot-full";
    runtimeInputs = [ pkgs.grim pkgs.wl-clipboard ];
    text = ''
      grim - | wl-copy -t image/png
    '';
  };
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    home.packages = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      screenshot-region
      screenshot-full
    ];

    xdg.desktopEntries.screenshot-region = {
      name = "Screenshot Region";
      genericName = "Screenshot Tool";
      exec = "${screenshot-region}/bin/screenshot-region";
      categories = [ "Utility" "Graphics" ];
      comment = "Select a region and copy screenshot to clipboard";
      terminal = false;
      type = "Application";
    };

    xdg.desktopEntries.screenshot-full = {
      name = "Screenshot Full";
      genericName = "Screenshot Tool";
      exec = "${screenshot-full}/bin/screenshot-full";
      categories = [ "Utility" "Graphics" ];
      comment = "Screenshot entire screen and copy to clipboard";
      terminal = false;
      type = "Application";
    };
  };
}
