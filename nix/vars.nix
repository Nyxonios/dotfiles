{ pkgs, lib ? pkgs.lib, ... }:
let
  # Import the machine types enum
  # This defines: Darwin, NixOS, Linux
  # See machine-types.nix for documentation on each option
  machineTypes = import ./machine-types.nix;
  
  # Helper to get all enum values for validation
  machineTypeValues = builtins.attrValues machineTypes;
  
  # ============================================================================
  # CONFIGURE YOUR MACHINE TYPE HERE
  # ============================================================================
  # Set this to one of the machineTypes options:
  #   machineTypes.Darwin  - for macOS with nix-darwin
  #   machineTypes.NixOS   - for NixOS systems
  #   machineTypes.Linux   - for standalone Linux with home-manager
  # ============================================================================
  machineType = machineTypes.Darwin;
  
  # Validate that machineType is one of the allowed values
  _ = lib.assertMsg (builtins.elem machineType machineTypeValues)
    "machineType must be one of: ${builtins.concatStringsSep ", " machineTypeValues}, but got: ${machineType}";
in
{
  inherit machineType machineTypes;
  
  userData = rec {
    user = "nyxonios";
    homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
    userEmail = "mseller@evroc.com";
    platform = "aarch64-darwin";
  };
}
