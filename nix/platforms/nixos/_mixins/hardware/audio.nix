# Audio Configuration (PipeWire)
# Applies to all desktop NixOS systems

{ config, pkgs, lib, host, customLib, ... }:

{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "") && host.platform == "nixos") {
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
    environment.systemPackages = with pkgs; [
      pavucontrol
    ];
  };
}
