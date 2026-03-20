# Shell Configuration
# Sets up zsh as the default shell on NixOS

{ config, lib, host, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    programs.zsh.enable = true;
    users.defaultUserShell = config.nixpkgs.pkgs.zsh;
  };
}
