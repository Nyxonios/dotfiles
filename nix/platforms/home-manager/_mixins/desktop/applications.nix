# NixOS Desktop Applications
# Linux-specific apps with configuration

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
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
  };
}
