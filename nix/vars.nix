# Local machine-specific configuration
{ pkgs, machineTypes, ... }:
{
  machineType = machineTypes.Darwin;
  userData = rec {
    user = "nyxonios";
    homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
    userEmail = "mseller@evroc.com";
    platform = "aarch64-darwin";
  };
}
