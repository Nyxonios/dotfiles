# Audio Configuration (PipeWire)
# Applies to all desktop NixOS systems

{ config, lib, host, ... }:

let
  isDesktop = host.desktop or false;
in
{
  config = lib.mkIf (isDesktop && host.platform == "nixos") {
    # Disable PulseAudio, enable PipeWire
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      audio.enable = true;
      alsa = {
        enable = true;
        support32Bit = false;
      };
    };

    # Audio control GUI
    environment.systemPackages = with config.nixpkgs.pkgs; [
      pavucontrol
    ];
  };
}
