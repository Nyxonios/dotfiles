# lldb-zig — Zig-aware LLDB fork (jacobly0/llvm-project)
#
# Installs zig-lldb, zig-lldb-dap and zig-lldb-server on PATH.
# Used by nvim-dap (see .config/nvim/lua/nyxonios/plugins/debug.lua) to debug
# Zig binaries built by the self-hosted backend (Zig 0.16 default).
#
# Gated to x86_64 Linux: the LLVM fork is heavy to build and the personal
# machines that need it (odin, hephaestus) are x86_64-linux.

{ config, pkgs, lib, host, customLib, ... }:

let
  lldb-zig = pkgs.callPackage ../../../../pkgs/lldb-zig { };
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isx86_64 && pkgs.stdenv.hostPlatform.isLinux) {
    home.packages = [ lldb-zig ];
  };
}
