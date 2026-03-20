# Hyprland Window Manager
# Self-gating: Only activates on desktop systems

{ config, lib, host, inputs, ... }:

let
  isDesktop = host.desktop or false;
  isNixOS = host.platform == "nixos";
in
{
  imports = lib.mkIf (isDesktop && isNixOS) [
    inputs.hyprland.nixosModules.default
  ];

  config = lib.mkIf (isDesktop && isNixOS) {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # Environment variables for Wayland/NVIDIA
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_SESSION_TYPE = "wayland";
      CLUTTER_BACKEND = "wayland";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    };

    # Additional environment variables for NVIDIA
    environment.variables = lib.mkIf (builtins.elem "nvidia" (host.gpu or [ ])) {
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
      WLR_RENDERER = "gles2";
      __GL_SYNC_TO_VBLANK = "0";
    };

    # System packages for Hyprland
    environment.systemPackages = with config.nixpkgs.pkgs; [
      hyprcursor
    ];
  };
}
