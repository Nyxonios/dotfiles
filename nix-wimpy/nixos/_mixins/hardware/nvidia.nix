# NVIDIA GPU Configuration
# Self-gating: Only activates on systems with NVIDIA GPU

{ config, lib, host, ... }:

let
  hasNvidia = builtins.elem "nvidia" (host.gpu or [ ]);
in
{
  config = lib.mkIf (hasNvidia && host.platform == "nixos") {
    # Enable NVIDIA drivers
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };

    # Hardware acceleration packages
    environment.systemPackages = with config.nixpkgs.pkgs; [
      mesa-demos
      libva-utils
      vdpauinfo
    ];
  };
}
