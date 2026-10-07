# Home Manager Nix Garbage Collection
# Only enabled for standalone home-manager targets (not NixOS/Darwin submodules
# which already have system-level GC configured via their respective modules).

{ lib, host, ... }:

{
  nix.gc = lib.mkIf (host.platform == "home-manager") {
    automatic = true;
    dates = "weekly";
  };
}
