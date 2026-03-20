# Development Tools

{ config, pkgs, lib, host, ... }:

{
  config = {
    home.packages = [
      # Containers/Kubernetes
      pkgs.kubectl
      pkgs.kustomize
      pkgs.k9s

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

      # AI assistants
      pkgs.opencode

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
