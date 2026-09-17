# Custom local packages
# These can be built using 'nix build .#<package-name>'

pkgs: {
  pi = pkgs.callPackage ./pi { };

  # Add your custom packages here as needed
  # Each package should be in its own directory with a default.nix
}
