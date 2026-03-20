# Development Mixins
# Languages, language servers, formatters, and dev tools

{ ... }:

{
  imports = [
    ./languages.nix
    ./tools.nix
    ./git.nix
  ];
}
