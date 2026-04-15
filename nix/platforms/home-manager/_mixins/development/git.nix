# Git Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.git = {
      enable = true;
      signing.format = "openpgp";

      settings = {
        user.name = host.username;
        user.email = host.email;

        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
      };
    };
  };
}
