# Home Manager Configuration
# User-level programs and dotfiles

{ config, pkgs, lib, host, inputs, overlays, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  imports = [
    # Desktop mixins
    ./_mixins/desktop

    # Development mixins
    ./_mixins/development

    # Terminal mixins
    ./_mixins/terminal

    # Services mixins
    ./_mixins/services
  ];

  # Enable XDG
  xdg.enable = true;

  # Home activation scripts
  home.activation.setupDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ~/development
    mkdir -p ~/docs
  '';

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home state version
  home.stateVersion = "24.05";
}
