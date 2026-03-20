# VM/Home Manager Configuration
# Minimal configuration for VMs or non-NixOS Linux systems

{ config, pkgs, lib, host, ... }:

{
  # VM-specific packages (these extend the base home-manager packages)
  home.packages = [
    pkgs.devenv
    pkgs.direnv
    pkgs.minio-warp
    pkgs.grpcurl
    pkgs.lsof
    pkgs.xclip
  ];
}
