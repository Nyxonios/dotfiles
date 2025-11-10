{ pkgs, ... }:
let
in
{
  home.packages = [
    pkgs.vault
    pkgs.devenv
    pkgs.direnv
  ];
}
