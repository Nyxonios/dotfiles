# Darwin Common System Configuration
# Applies to all Darwin systems

{ config, lib, host, pkgs, customLib, ... }:

{
  config = customLib.mkIfPlatform "darwin" {
    # System platform
    nixpkgs.hostPlatform = host.system;

    # Darwin state version
    system.stateVersion = 5;

    # Set primary user from host metadata
    system.primaryUser = host.username;
    users.users.${host.username} = {
      home = host.home;
      shell = pkgs.zsh;
    };

    # Git commit hash for darwin-version
    system.configurationRevision = config.self.rev or config.self.dirtyRev or null;
  } host;
}
