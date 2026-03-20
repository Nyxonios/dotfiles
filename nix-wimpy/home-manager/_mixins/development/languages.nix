# Programming Languages and Language Servers

{ config, pkgs, lib, host, ... }:

{
  config = {
    home.packages = [
      # Go
      pkgs.go
      pkgs.delve
      pkgs.gopls
      pkgs.gofumpt

      # Zig
      pkgs.zigpkgs.master
      pkgs.zls

      # Rust
      pkgs.rustup

      # Nix
      pkgs.nixd
      pkgs.nixpkgs-fmt

      # Shell
      pkgs.shellcheck
      pkgs.bash-language-server

      # Lua
      pkgs.lua-language-server
      pkgs.stylua

      # C/C++
      pkgs.clang-tools
      pkgs.cmake
      pkgs.ninja

      # Other languages
      pkgs.odin
      pkgs.ansible
      pkgs.bun

      # JavaScript/TypeScript (Node already in host config for work)
      pkgs.nodejs_20
      pkgs.typescript
      pkgs.prettierd

      # Additional tools
      pkgs.cloc
      pkgs.sqlite
      pkgs.git-lfs
    ];
  };
}
