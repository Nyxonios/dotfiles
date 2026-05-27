# NVIDIA GPU Configuration
# Self-gating: Only activates on systems with NVIDIA GPU

{ config, pkgs, lib, host, ... }:

let
  hasNvidia = builtins.elem "nvidia" (host.gpu or [ ]);
in
{
  config = lib.mkIf (hasNvidia && host.platform == "nixos") {
    # Enable NVIDIA drivers
    services.xserver.videoDrivers = [ "nvidia" ];

    # Enable graphics support (OpenGL/Vulkan)
    # Required for any graphical session including Wayland/Hyprland
    hardware.graphics.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    };

    # Environment variables for NVIDIA + Wayland/Hyprland
    environment.variables = {
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
      __GL_SYNC_TO_VBLANK = "0";
      WLR_RENDERER = "gles2";

      # Critical: prevents black screen on NVIDIA with atomic DRM
      WLR_DRM_NO_ATOMIC = "1";

      # Disable G-Sync and VRR to prevent display issues
      __GL_GSYNC_ALLOWED = "0";
      __GL_VRR_ALLOWED = "0";
    };

    # Hardware acceleration packages
    environment.systemPackages = with pkgs; [
      mesa-demos
      libva-utils
      vdpauinfo
    ];
  };
}
