# Common configuration shared between NixOS and Darwin
# This is where overlays and common settings are applied

{ config, inputs, lib, outputs, pkgs, host, ... }:

{
  # Common packages available on all platforms
  environment = {
    systemPackages = with pkgs; [
      git
      just
      jq
      yq
      fzf
      ripgrep
    ];

    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  # Hostname from host metadata
  networking.hostName = host.name;

  # Nixpkgs configuration with overlays
  nixpkgs = {
    overlays = [
      # Overlays defined in overlays/default.nix
      outputs.overlays.localPackages
      outputs.overlays.modifiedPackages
      outputs.overlays.stablePackages
      outputs.overlays.zigOverlay
    ];

    config = {
      allowUnfree = true;
    };
  };

  # Nix configuration
  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;

        # Enable flakes
        experimental-features = [ "nix-command" "flakes" ];
      };

      # Disable channels
      channel.enable = false;

      # Make flake registry and nix path match flake inputs
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      # Enable automatic garbage collection
      gc = {
        automatic = true;
      };
    };

  # Enable zsh shell by default
  programs.zsh.enable = true;

  # Set zsh as the default shell for all users
  users.defaultUserShell = pkgs.zsh;

  # Font configuration for all systems
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
    ];
  };
}
