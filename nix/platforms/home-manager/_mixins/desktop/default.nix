# Desktop Mixins for Home Manager
# GUI applications and desktop customization

{ ... }:

{
  imports = [
    ./vscode.nix
    ./browsers.nix
    ./waybar.nix
    ./mako.nix
    ./applications.nix
    ./hypr.nix
    ./rofi.nix
    ./wleave.nix
    ./universal-apps.nix
    ./darwin-apps.nix
  ];
}
