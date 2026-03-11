# Local machine-specific configuration
{ machineTypes, ... }:
{
  userData = rec {
    user = "";
    machineType = machineTypes.Linux;
    homeDir = if machineType == machineTypes.Darwin then "/Users/${user}" else "/home/${user}";
    userEmail = "";
    platform = if machineType == machineTypes.Darwin then "aarch64-darwin" else "x86_64-linux";
  };
}

