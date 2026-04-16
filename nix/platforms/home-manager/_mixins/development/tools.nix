# Development Tools that require no configuration

{ config, pkgs, lib, host, ... }:
{
  config = {
    # Configuration files for CLI tools

    home.packages = [
      # Task runner
      pkgs.just


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

      pkgs.gcc

    ] ++ lib.optionals (host.formFactor == "vm" && builtins.elem "work" (host.tags or [ ])) [
      pkgs.devenv
      pkgs.direnv
      pkgs.lsof
      pkgs.kubectl
      pkgs.kustomize
    ];
  };
}
