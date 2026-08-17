# Local bin scripts (public)

This directory is for public, non-secret scripts that should be installed into
`~/.local/bin` by the Nix / Home Manager configuration.

## How to add a script

1. Drop your script here.
2. Make it executable (`chmod +x`).
3. Declare it in `nix/platforms/home-manager/_mixins/bin/default.nix`:

```nix
home.file.".local/bin/my-script" = {
  source = "${host.home}/dotfiles/bin/my-script";
  executable = true;
};
```

4. Rebuild: `rebuild`

## Secret scripts

Do **not** commit work-specific or secret scripts here. Those stay in the
private `~/bin` repository (`git@gitlab.evroc.dev:mseller/work-scripts.git`).
Nix symlinks them into `~/.local/bin` at activation time so they never enter
the world-readable Nix store.
