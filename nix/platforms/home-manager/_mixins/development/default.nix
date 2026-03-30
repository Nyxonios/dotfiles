# Development Mixins
# Languages, language servers, formatters, and dev tools

{ ... }:

{
  imports = [
    ./tools.nix
    ./languages.nix
    ./git.nix
    ./neovim.nix
    ./k9s.nix
    ./opencode.nix
  ];
}
