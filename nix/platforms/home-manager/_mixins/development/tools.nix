# Development Tools that require no configuration

{ config, pkgs, lib, host, ... }:
{
  config = {
    # Configuration files for CLI tools

    home.packages = [
      # Task runner
      pkgs.just

      # Containers/Kubernetes
      pkgs.kubectl
      pkgs.kustomize

      # Version control
      pkgs.lazygit

      # Search and utilities
      pkgs.ripgrep
      pkgs.jq
      pkgs.yq-go

      # System monitoring
      pkgs.btop

      # Build tools
      pkgs.gnumake42

      # Secrets
      pkgs.vault-bin

      # SOPS tools (age encryption)
      pkgs.age
      pkgs.ssh-to-age

      # GitLab
      pkgs.glab

      # Code analysis
      pkgs.glsl_analyzer

      # VM-specific tools (only on VMs)
    ] ++ lib.optionals (host.platform == "home-manager") [
      pkgs.devenv
      pkgs.direnv
      pkgs.minio-warp
      pkgs.graphviz
      pkgs.awscli2
      pkgs.s3cmd
      pkgs.grpcurl
      pkgs.lsof
      pkgs.xclip
    ];
  };
}
