# Local machine-specific configuration
{ machineTypes, ... }:
{
  userData = rec {
    user = "";
    machineType = machineTypes.Linux;
    homeDir = if machineType == machineTypes.Darwin then "/Users/${user}" else "/home/${user}";
    userEmail = "";
    arch = "";
    os = if machineType == machineTypes.Darwin then "darwin" else "linux";
    platform = "${arch}-${os}";
  };
}

