# Darwin Desktop Applications
# macOS-specific apps with configuration symlinks

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isDarwin = host.platform == "darwin";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isDarwin && isDesktop) {
    home.packages = [
      pkgs.aerospace
      pkgs.karabiner-elements
    ];

    xdg.configFile.aerospace.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/aerospace";
    xdg.configFile.karabiner.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/karabiner";
  };
}
