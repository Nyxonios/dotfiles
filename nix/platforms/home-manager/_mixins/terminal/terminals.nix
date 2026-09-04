# Terminal Emulators
# Ghostty for all desktop systems
# - Linux: installed via nixpkgs
# - Darwin: installed via Homebrew cask
# Not installed on VMs

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isDesktop = customLib.isDesktop (host.formFactor or "");
  isLinux = host.platform != "darwin";
in
{
  config = lib.mkIf isDesktop (lib.mkMerge [
    # Linux: Install ghostty from nixpkgs
    (lib.mkIf isLinux {
      home.packages = [ pkgs.ghostty ];
    })
    # All platforms: Ghostty main config
    {
      xdg.configFile."ghostty/config".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty/config";
    }
    # All platforms: Ghostty theme
    {
      xdg.configFile."ghostty/themes/catppuccin-mocha".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty/themes/catppuccin-mocha";
    }
    # Linux: Generate Linux-specific config file
    (lib.mkIf isLinux {
      xdg.configFile."ghostty/linux-config".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty/linux-config";
    })
  ]);
}
