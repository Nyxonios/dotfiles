{ pkgs }:

let
  # Phase 1: reproducibly fetch the npm tarball and install its dependencies.
  # This is a fixed-output derivation so it is allowed to talk to the npm
  # registry.  The hash must be updated whenever the pi version changes.
  #
  # To update:
  #   1. Change `version` below.
  #   2. Run `nix-prefetch-url` for the new tarball to get `src` hash.
  #   3. Build once with a dummy `outputHash` to let Nix tell you the real one,
  #      or use `nix-prefetch-...` if available.
  piWithDeps = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "pi-coding-agent-deps";
    version = "0.85.1";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
      hash = "sha256-H0mHKWSb3OZH0RYJk7TZK/PGFMyBkhO+4vkd008qevQ=";
    };

    nativeBuildInputs = [ pkgs.nodejs pkgs.cacert ];

    buildPhase = ''
      export HOME=$TMPDIR
      export npm_config_cache=$TMPDIR/npm-cache
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      mkdir -p $TMPDIR/pkg
      tar xzvf $src -C $TMPDIR/pkg
      cd $TMPDIR/pkg/package
      npm install --ignore-scripts --omit=dev
    '';

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHash = "sha256-guJncgjupa6sYwCtR3KkDeuI8JQrlYQ0qnmgg5pgXaE=";
    outputHashMode = "recursive";
  };
in

# Phase 2: wrap the Node.js runtime around the pre-built CLI bundle.
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "pi-coding-agent";
  inherit (piWithDeps) version;

  dontUnpack = true;
  dontConfigure = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  buildPhase = ''
    mkdir -p $out/lib/node_modules/@earendil-works/pi-coding-agent
    cp -r ${piWithDeps}/. $out/lib/node_modules/@earendil-works/pi-coding-agent/
  '';

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/pi \
      --add-flags "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
  '';

  meta = {
    description = "Pi coding agent — AI-powered terminal coding assistant";
    mainProgram = "pi";
  };
}
