# NixOS Common System Configuration
# Applies to all NixOS systems

{ config, lib, host, pkgs, ... }:

{
  config = lib.mkIf (host.platform == "nixos") {
    # System platform
    nixpkgs.hostPlatform = host.system;

    # Timezone
    time.timeZone = "Europe/Stockholm";

    # Locale
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "sv_SE.UTF-8";
      LC_IDENTIFICATION = "sv_SE.UTF-8";
      LC_MEASUREMENT = "sv_SE.UTF-8";
      LC_MONETARY = "sv_SE.UTF-8";
      LC_NAME = "sv_SE.UTF-8";
      LC_NUMERIC = "sv_SE.UTF-8";
      LC_PAPER = "sv_SE.UTF-8";
      LC_TELEPHONE = "sv_SE.UTF-8";
      LC_TIME = "sv_SE.UTF-8";
    };

    # User account
    users.users.${host.username} = {
      isNormalUser = true;
      description = host.username;
      extraGroups = [ "networkmanager" "wheel" ];
      shell = pkgs.zsh;
    };

    # Set zsh as the default shell for new users
    users.defaultUserShell = pkgs.zsh;

    # System state version
    system.stateVersion = "23.11";
  };
}
