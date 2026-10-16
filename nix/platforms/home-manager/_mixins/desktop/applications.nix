# NixOS Desktop Applications
# Linux-specific apps with configuration

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isLinux = host.platform == "nixos" || host.platform == "home-manager";
  isDesktop = customLib.isDesktop (host.formFactor or "");

  # Wrapped OBS with NVENC support + plugins on NixOS.
  # wrapOBS bundles OBS plugins; symlinkJoin + wrapProgram adds the NVIDIA driver lib
  # path so obs-nvenc-test can find libnvidia-encode.so at runtime.
  obs-studio-nvenc = let
    obs-with-plugins = pkgs.wrapOBS {
      plugins = [ pkgs.obs-studio-plugins.obs-aitum-multistream ];
    };
  in pkgs.symlinkJoin {
    name = "obs-studio";
    paths = [ obs-with-plugins ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/obs \
        --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib"
    '';
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (isLinux && isDesktop) {
      home.packages = [
        # Content creation (Linux-specific or better on Linux)
        obs-studio-nvenc

      # Communication (mattermost-desktop is broken on Darwin - macOS deployment target issue)
      pkgs.mattermost-desktop
      pkgs.signal-desktop

        # Office suite (LibreOffice works on macOS but you probably use MS Office/iWork)
        pkgs.libreoffice
      ];
    })

    (lib.mkIf (isNixOS && isDesktop) {
      # Pointer cursor theme (GTK/X11/Wayland specific)
      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 22;
      };
    })
  ];
}
