# Git Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.git = {
      enable = true;

      settings = {
        user.name = host.username;
        user.email = host.email;

        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;

        alias = {
          st = "status";
          co = "checkout";
          br = "branch";
          ci = "commit";
          unstage = "reset HEAD --";
          last = "log -1 HEAD";
          visual = "!gitk";
        };
      };
    };
  };
}
