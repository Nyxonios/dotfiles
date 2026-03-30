# Desktop Applications
# Organized by platform for clarity

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = lib.mkMerge [
    # ============================================================================
    # Desktop Applications
    # ============================================================================
    (customLib.mkIfDesktop
      (lib.mkMerge [
        # Universal Configs (All Form Factors)
        {
          home.packages = [
            # Productivity
            pkgs.obsidian

            # Communication
            pkgs.telegram-desktop

            # Media
            pkgs.spotify
          ];
        }

        # Desktop-only Applications (laptop/desktop form factors)
        (customLib.mkIfPlatform "darwin"
          {
            home.packages = [
              pkgs.aerospace
              pkgs.karabiner-elements
            ];

            xdg.configFile.aerospace.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/aerospace";
            xdg.configFile.karabiner.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/karabiner";
          }
          host)

        # NixOS/Linux Specific
        (customLib.mkIfPlatform "nixos"
          {
            home.packages = [
              # Content creation (Linux-specific or better on Linux)
              pkgs.obs-studio

              # Communication (mattermost-desktop is broken on Darwin - macOS deployment target issue)
              pkgs.mattermost-desktop

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
          }
          host)
      ])
      host)
  ];
}
