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

  # Linux-specific Ghostty config
  ghosttyLinuxConfig = ''
    # Linux-specific Ghostty settings
    # This file is only loaded on Linux systems (via conditional config)

    # Disable clipboard copy notifications (Linux/GTK only)
    app-notifications = no-clipboard-copy
  '';
in
{
  config = lib.mkIf isDesktop (lib.mkMerge [
    # Linux: Install ghostty from nixpkgs
    (lib.mkIf isLinux {
      home.packages = [ pkgs.ghostty ];
    })
    # All platforms: Symlink ghostty main config
    {
      xdg.configFile."ghostty/config".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty/config";
    }
    # All platforms: Symlink ghostty themes directory
    {
      xdg.configFile."ghostty/themes".source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/ghostty/themes";
    }
    # Linux: Generate Linux-specific config file
    (lib.mkIf isLinux {
      xdg.configFile."ghostty/linux-config".text = ghosttyLinuxConfig;
    })
  ]);
}
