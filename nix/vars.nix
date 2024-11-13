{ pkgs, ... }:
{
  userData = rec {
    user = "";
    homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
    userEmail = "";
    platform = "";
  };
}

