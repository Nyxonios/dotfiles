# Gaming Configuration for NixOS
# Self-gating: Only activates on hosts tagged with "gaming"
#
# This module sets up the full gaming stack needed to play World of Warcraft
# and other Battle.net/Windows games via Lutris + Wine.
#
# Included setup:
#   - 32-bit graphics drivers (required by Battle.net agent / Wine)
#   - Steam (pulls in Vulkan gaming dependencies even if unused)
#   - Gamemode (performance daemon)
#   - Lutris with Wine staging + winetricks + libnghttp2
#   - Useful extras: mangohud, gamescope, vulkan-tools, protonup-ng
#
# Important Battle.net / WoW on NixOS notes:
#   - If the Battle.net installer/agent crashes on first run, kill it and
#     relaunch. This is a common Wine-on-NixOS quirk.
#   - On Wayland (Hyprland) the Battle.net launcher window may appear as a
#     blank/black rectangle. Workaround: launch it inside gamescope once to
#     install the game, then launch WoW directly afterwards.
#   - If camera rotation stops when the mouse hits the screen edge, that is
#     the known NixOS mouse-warping issue (see nixpkgs issue #333806).
#     Running the game inside gamescope usually fixes it.

{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfTag "gaming"
    {
      # =========================================================================
      # Core Graphics / Driver Support
      # =========================================================================

      # 32-bit support is MANDATORY for Battle.net installer, Wine, and DXVK.
      # This is independent of the "enable = true" already set in nvidia.nix.
      hardware.graphics.enable32Bit = lib.mkDefault true;

      # =========================================================================
      # Programs
      # =========================================================================

      # Enabling Steam is the quickest way to pull in the full Vulkan/32-bit
      # gaming dependency stack on NixOS, even if you run WoW through Lutris.
      programs.steam.enable = true;

      # Gamemode optimises CPU governor and process priority while gaming.
      programs.gamemode.enable = true;

      # =========================================================================
      # Gaming Packages
      # =========================================================================

      environment.systemPackages = with pkgs; [
        # Lutris — open-source game manager that automates Wine prefixes,
        # installers, and runner configuration.  We override extraPkgs so
        # the FHS environment contains the correct Wine build and helpers.
        (lutris.override {
          extraPkgs = pkgs: [
            # Full staging build of Wine (64+32 bit).  This is what the NixOS
            # community reports as the most compatible with Battle.net / WoW.
            pkgs.wineWow64Packages.stagingFull
            pkgs.winetricks
            # Required so Lutris can download the Battle.net installer over
            # HTTPS without certificate errors.
            pkgs.libnghttp2
          ];
        })

        # In-system copies of winetricks / vulkan-tools for troubleshooting
        winetricks
        vulkan-tools

        # Performance overlay (FPS, frametime, …)
        mangohud

        # Micro-compositor that helps with Wayland/NVIDIA quirks (blank
        # launcher window, mouse-warping bug, resolution/scaling issues).
        gamescope

        # Manage Proton-GE versions when running games through Steam.
        protonup-ng
      ];

      # =========================================================================
      # Environment Tweaks
      # =========================================================================

      # Unset DISPLAY for Wine when running under native Wayland so Wine 10+
      # uses its built-in Wayland driver.  This avoids XWayland bugs in
      # Hyprland (e.g. window-switching problems, high input latency).
      # Only affects Lutris games if you explicitly add DISPLAY="" there.
      environment.sessionVariables = {
        # Let Wine 10+ pick Wayland natively when possible (Lutris per-game
        # override still available if something breaks).
        # DISPLAY = "";
      };

    }
    host;
}
