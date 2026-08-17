{ config, lib, pkgs, host, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  privateBinDir = "${host.home}/bin";
  localBinDir = "${host.home}/.local/bin";
in
{
  # ============================================================================
  # Public scripts
  # ============================================================================
  # Place scripts you want publicly version-controlled in the dotfiles repo
  # under ~/dotfiles/bin/ and add them here.
  #
  # Example:
  # home.file.".local/bin/my-public-script" = {
  #   source = "${host.home}/dotfiles/bin/my-public-script";
  #   executable = true;
  # };
  #
  # For simple one-liners you can also use:
  # home.packages = [ (pkgs.writeShellScriptBin "foo" ''echo bar'') ];
  # ============================================================================

  # ============================================================================
  # Private scripts (from ~/bin / work-scripts.git)
  # ============================================================================
  # We symlink rather than copy so that:
  #   1. Secrets never enter the world-readable Nix store.
  #   2. Edits in the private repo are immediately live (no rebuild needed).
  # ============================================================================
  home.activation.linkPrivateBin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PRIV="${privateBinDir}"
    LOCAL="${localBinDir}"

    mkdir -p "$LOCAL"

    if [ -d "$PRIV" ]; then
      # Top-level shell scripts (e.g. work.sh, essh.sh)
      for f in "$PRIV"/*.sh; do
        [ -f "$f" ] && ln -sf "$f" "$LOCAL/$(basename "$f")"
      done

      # Compiled binaries (e.g. extract-image-tags, mr-list)
      if [ -d "$PRIV/bins" ]; then
        for b in "$PRIV/bins"/*; do
          [ -f "$b" ] && ln -sf "$b" "$LOCAL/$(basename "$b")"
        done
      fi

      # Individual executable helper scripts
      if [ -d "$PRIV/scripts" ]; then
        for s in "$PRIV/scripts"/*; do
          [ -x "$s" ] && ln -sf "$s" "$LOCAL/$(basename "$s")"
        done
      fi
    fi
  '';

  # ============================================================================
  # Legacy cleanup
  # ============================================================================
  # Optionally remove old clutter that used to live directly in ~/bin copies.
  # Uncomment once you've verified the ~/.local/bin setup is complete.
  # ============================================================================
  # home.activation.removeLegacyBinFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   rm -f "${host.home}/bin/*.bak"
  # '';
}
