# Desktop Mixins for Home Manager
# GUI applications and desktop customization

{ ... }:

{
  imports = [
    ./vscode.nix
    ./browsers.nix
    ./waybar.nix
    ./applications.nix
    ./hypr.nix
    ./rofi.nix
    ./wleave.nix
  ];
}
