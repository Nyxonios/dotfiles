# Audio Configuration (PipeWire)
# Applies to all desktop NixOS systems

{ config, pkgs, lib, host, customLib, ... }:

{
  config = customLib.mkIfNixOSDesktop {
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
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Audio control GUI and media key support
    environment.systemPackages = with pkgs; [
      pavucontrol
      playerctl  # MPRIS controller for media keys
    ];
  } host;
}
