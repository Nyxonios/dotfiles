{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
  
  wleaveLayout = pkgs.writeText "wleave-layout.json" (builtins.toJSON {
    margin = 550;
    buttons-per-row = "5";
    button-aspect-ratio = "1";
    column-spacing = 4;
    row-spacing = 8;
    show-keybinds = false;
    close-on-lost-focus = true;
    css = "${host.home}/.config/wleave/style.css";
    buttons = [
      {
        label = "lock";
        action = "loginctl lock-session";
        text = "Lock";
        keybind = "l";
        icon = "${host.home}/.config/wleave/icons/lock.svg";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit 0";
        text = "Logout";
        keybind = "e";
        icon = "${host.home}/.config/wleave/icons/logout.svg";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
        icon = "${host.home}/.config/wleave/icons/shutdown.svg";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
        icon = "${host.home}/.config/wleave/icons/suspend.svg";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
        icon = "${host.home}/.config/wleave/icons/reboot.svg";
      }
    ];
  });
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    home.packages = [ pkgs.wleave ];
    # Symlink individual icon files
    xdg.configFile."wleave/icons/lock.svg".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/icons/lock.svg";
    xdg.configFile."wleave/icons/logout.svg".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/icons/logout.svg";
    xdg.configFile."wleave/icons/shutdown.svg".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/icons/shutdown.svg";
    xdg.configFile."wleave/icons/suspend.svg".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/icons/suspend.svg";
    xdg.configFile."wleave/icons/reboot.svg".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/icons/reboot.svg";
    
    xdg.configFile."wleave/style.css".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wleave/style.css";
    
    # Generate layout.json with correct home directory path
    xdg.configFile."wleave/layout.json".source = wleaveLayout;
  };
}