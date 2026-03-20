# Git Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.git = {
      enable = true;
      userName = host.username;
      userEmail = host.email;

      extraConfig = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
      };

      aliases = {
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
}
