{ pkgs, ... }:
let
  inherit (import ./../../vars.nix { inherit pkgs; }) userData;
in
{
  imports = [
    ./waybar/waybar.nix
  ];

  programs.hyprland.enable = true;
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
  };
  hardware = {
    graphics.enable = true;
    nvidia.modesetting.enable = true;
  };

  environment.systemPackages = with pkgs;[
    hyprpaper
    hyprshot
    swaynotificationcenter
    libnotify

    rofi-wayland
    wlogout
  ];

  # Setup all needed configuration files.
  # I currently dont want to configure all these 
  # programs via nix, so we create out of store
  # symlinks to them instead.
  home-manager.users."${userData.user}" = { config, ... }:
    let
      inherit (config.lib.file) mkOutOfStoreSymlink;
    in
    {
      xdg.configFile."hypr".source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/hypr;
      xdg.configFile."rofi".source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/rofi;
      xdg.configFile."wlogout".source = mkOutOfStoreSymlink userData.homeDir + /dotfiles/.config/wlogout;
    };

}
