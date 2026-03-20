# Overlays
# https://nixos.wiki/wiki/Overlays

{ inputs, ... }:

{
  # Local packages from the pkgs directory
  localPackages = final: _prev: import ../pkgs final.pkgs;

  # Modified packages - version overrides, patches, compilation flags
  modifiedPackages = final: prev: {
    # Pin catppuccin tmux plugin to a specific version
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

    # Pin karabiner-elements to a specific version (for macOS)
    karabiner-elements = prev.karabiner-elements.overrideAttrs (old: {
      version = "14.13.0";
      src = prev.fetchurl {
        inherit (old.src) url;
        hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
      };
    });
  };

  # Stable packages from nixpkgs-stable
  stablePackages = final: prev:
    let
      pkgs-stable = import inputs.nixpkgs-stable {
        system = prev.stdenv.hostPlatform.system;
        config = { allowUnfree = true; };
      };
    in
    {
      zsh = pkgs-stable.zsh;
      fzf = pkgs-stable.fzf;
      zsh-fzf-tab = pkgs-stable.zsh-fzf-tab;
    };

  # External overlays from flake inputs
  zigOverlay = inputs.zig.overlays.default;
}
