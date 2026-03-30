# Desktop Applications
# Organized by platform for clarity

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = lib.mkMerge [
    # ============================================================================
    # Universal Configs (All Form Factors)
    # These configs apply to VMs, laptops, and desktops alike
    # ============================================================================
    {
      xdg.configFile.k9s.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/k9s";
      xdg.configFile.opencode.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/opencode";
    }

    # ============================================================================
    # Desktop-only Applications (laptop/desktop form factors)
    # ============================================================================
    (lib.mkIf (customLib.isDesktop (host.formFactor or "")) (lib.mkMerge [
      # Shared Desktop Applications (All Platforms)
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
      }

      # Darwin/macOS Specific
      (lib.mkIf (host.platform == "darwin") {
        xdg.configFile.aerospace.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/aerospace";
        xdg.configFile.karabiner.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/karabiner";
      })

      # NixOS/Linux Specific
      (lib.mkIf (host.platform == "nixos") {
        home.packages = [
          # Content creation (Linux-specific or better on Linux)
          pkgs.obs-studio

          # Office suite (LibreOffice works on macOS but you probably use MS Office/iWork)
          pkgs.libreoffice
        ];

        # Pointer cursor theme (GTK/X11/Wayland specific)
        home.pointerCursor = {
          gtk.enable = true;
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
          size = 22;
        };
      })
    ]))
  ];
}
