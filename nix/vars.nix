# Local machine-specific configuration
{ pkgs, machineTypes, ... }:
{
  machineType = machineTypes.Darwin;
  userData = rec {
    user = "";
    homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
    userEmail = "";
    platform = "";
  };
}
