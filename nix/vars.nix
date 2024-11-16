{ pkgs, ... }:
{
  userData = rec {
    user = "nyxonios";
    homeDir = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
    userEmail = "martin.n.seller@gmail.com";
    platform = "x86_64-linux";
  };
}

