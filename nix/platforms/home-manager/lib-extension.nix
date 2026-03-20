# Lib extension module for Home Manager
# This module extends the lib with our custom functions

{ lib, ... }:

let
  # Import our custom lib
  customLib = import ../../lib { nixpkgs = { inherit lib; }; };
in
{
  # Extend lib with our custom functions
  config.lib = lib.mkForce (lib // customLib);
}
