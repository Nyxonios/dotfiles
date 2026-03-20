# NixOS Configuration Entry Point
# Imports all self-gating mixins - each module decides if it should activate

{ ... }:

{
  imports = [
    # Desktop mixins
    ./_mixins/desktop

    # Hardware mixins
    ./_mixins/hardware

    # Network mixins
    ./_mixins/network

    # Services mixins
    ./_mixins/services

    # Users mixins
    ./_mixins/users
  ];
}
