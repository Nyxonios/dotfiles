# Home Manager Configuration
# User-level programs and dotfiles

{ config, pkgs, lib, host, inputs, overlays, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  imports = [
    # Desktop mixins
    ./_mixins/desktop

    # Development mixins
    ./_mixins/development

    # Terminal mixins
    ./_mixins/terminal

    # Services mixins
    ./_mixins/services
  ];

  # Enable XDG
  xdg.enable = true;

  # Home activation scripts
  home.activation = {
    setupDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ~/development
      mkdir -p ~/docs
    '';

    # Install git hooks for secrets validation
    installGitHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DOTFILES="${config.home.homeDirectory}/dotfiles/nix"
      HOOK_SRC="$DOTFILES/scripts/pre-commit.hook"
      HOOK_DST="$DOTFILES/.git/hooks/pre-commit"
      
      if [[ -f "$HOOK_SRC" ]]; then
        mkdir -p "$DOTFILES/.git/hooks"
        if [[ ! -f "$HOOK_DST" ]] || [[ "$HOOK_SRC" -nt "$HOOK_DST" ]]; then
          cp "$HOOK_SRC" "$HOOK_DST"
          chmod +x "$HOOK_DST"
          echo "Installed/updated git pre-commit hook for secrets validation"
        fi
      fi
    '';
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Home state version
  home.stateVersion = "24.05";
}
