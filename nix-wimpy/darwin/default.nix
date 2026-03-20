# Darwin (macOS) Configuration Entry Point
# Imports all self-gating mixins - each module decides if it should activate

{ ... }:

{
  imports = [
    # Desktop mixins
    ./_mixins/desktop

    # Services mixins
    ./_mixins/services

    # System mixins
    ./_mixins/system
  ];
}
