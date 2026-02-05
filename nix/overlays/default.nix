# overlays/default.nix
# Consolidated overlays for the entire flake

{ inputs, system }:

let
  # Overlay for pinned packages using overrideAttrs
  tmuxPluginCatppuccinOverlay = final: prev: {
    # Pin catppuccin tmux plugin to specific version
    tmuxPlugins = prev.tmuxPlugins // {
      catppuccin = prev.tmuxPlugins.catppuccin.overrideAttrs (old: {
        version = "pinned";
        src = prev.fetchFromGitHub {
          owner = "catppuccin";
          repo = "tmux";
          rev = "v1.0.3";
          sha256 = "18ygayigzp7s9fv1fv65m0p6p1f4vjyzq079gm4qadlphn9nnk57"; # Run nix-prefetch-url or nix-prefetch-git to get actual hash
        };
      });
    };
  };

  # Overlay for karabiner-elements version pinning
  karabinerOverlay = final: super: {
    karabiner-elements = super.karabiner-elements.overrideAttrs (old: {
      version = "14.13.0";
      src = super.fetchurl {
        inherit (old.src) url;
        hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
      };
    });
  };

  # Zig overlay from the zig input
  zigOverlay = inputs.zig.overlays.default;

in
{
  # All overlays combined
  allOverlays = [
    zigOverlay
    tmuxPluginCatppuccinOverlay
    karabinerOverlay
  ];

  # Individual overlays for selective use
  inherit tmuxPluginCatppuccinOverlay karabinerOverlay zigOverlay;
}
