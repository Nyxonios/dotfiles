# Desktop Applications
# Organized by platform for clarity

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "")) (lib.mkMerge [
    # ============================================================================
    # Shared Desktop Applications (All Platforms)
    # These work on both macOS and Linux desktops
    # ============================================================================
    {
      home.packages = [
        # Productivity
        pkgs.obsidian

        # Communication
        pkgs.telegram-desktop
        pkgs.mattermost-desktop

        # Media
        pkgs.spotify
      ];

      # Application configs (shared across platforms)
      xdg.configFile.k9s.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/k9s";
      xdg.configFile.opencode.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/opencode";
    }

    # ============================================================================
    # Darwin/macOS Specific
    # Apps and configs that only make sense on macOS
    # ============================================================================
    (lib.mkIf (host.platform == "darwin") {
      xdg.configFile.aerospace.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/aerospace";
      xdg.configFile.karabiner.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/karabiner";
    })

    # ============================================================================
    # NixOS/Linux Specific
    # Apps and configs that only make sense on NixOS
    # ============================================================================
    (lib.mkIf (host.platform == "nixos") {
      home.packages = [
        # Content creation (Linux-specific or better on Linux)
        pkgs.obs-studio

        # Office suite (LibreOffice works on macOS but you probably use MS Office/iWork)
        pkgs.libreoffice
      ];

      # Window manager and desktop environment configs
      xdg.configFile.hypr.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/hypr";
      xdg.configFile.rofi.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/rofi";
      xdg.configFile.wlogout.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/wlogout";

      # Pointer cursor theme (GTK/X11/Wayland specific)
      home.pointerCursor = {
        gtk.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 22;
      };
    })
  ]);
}
