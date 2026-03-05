# overlays/default.nix
# Consolidated overlays for the entire flake

{ inputs, system, pkgs-stable }:

let

  # Overlay for pinned packages using overrideAttrs
  tmuxPluginCatppuccinOverlay = final: prev: {
    # Pin catppuccin tmux plugin to the version from nixpkgs rev 50165c4f7eb48ce82bd063e1fb8047a0f515f8ce
    tmuxPlugins = prev.tmuxPlugins // {
      catppuccin = prev.tmuxPlugins.catppuccin.overrideAttrs (old: {
        version = "unstable-2024-05-15";
        src = prev.fetchFromGitHub {
          owner = "catppuccin";
          repo = "tmux";
          rev = "697087f593dae0163e01becf483b192894e69e33";
          hash = "sha256-EHinWa6Zbpumu+ciwcMo6JIIvYFfWWEKH1lwfyZUNTo=";
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

  # Overlay to pin zsh, fzf, zsh-fzf-tab, and hyprland to stable nixpkgs version
  zshStableOverlay = final: prev: {
    zsh = pkgs-stable.zsh;
    fzf = pkgs-stable.fzf;
    zsh-fzf-tab = pkgs-stable.zsh-fzf-tab;
  };

  # Zig overlay from the zig input
  zigOverlay = inputs.zig.overlays.default;

  hyprlandOverlay = final: prev: {
    hyprland = pkgs-stable.hyprland;
    xdg-desktop-portal-hyprland = pkgs-stable.xdg-desktop-portal-hyprland;
  };

in
{
  # All overlays combined
  allOverlays = [
    zigOverlay
    tmuxPluginCatppuccinOverlay
    karabinerOverlay
    zshStableOverlay
    hyprlandOverlay
  ];

  # Individual overlays for selective use
  inherit tmuxPluginCatppuccinOverlay karabinerOverlay zigOverlay zshStableOverlay hyprlandOverlay;
}
