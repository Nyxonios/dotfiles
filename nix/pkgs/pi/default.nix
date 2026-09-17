{ pkgs
, piSrc ? pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-H0mHKWSb3OZH0RYJk7TZK/PGFMyBkhO+4vkd008qevQ=";
  }
, version ? "0.85.1"
, npmDepsHash ? {
    aarch64-darwin = "sha256-QVO552JAR2TxQ2x5hObg8VzZPmTLXUms2gypiBM1XXA=";
    x86_64-linux   = "sha256-TOcaCCWaWU5b53QCUYHQApcuJemgQykMfFWEFiOcqQE=";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "pi-coding-agent: no npmDepsHash known for ${pkgs.stdenv.hostPlatform.system}; build once with lib.fakeSha256 and add it here")
}:

let
  # Phase 1: reproducibly fetch the npm tarball or local directory, and install
  # its dependencies. This is a fixed-output derivation so it is allowed to
  # talk to the npm registry.
  #
  # Because `npm install` skips incompatible optionalDependencies, the installed
  # node_modules tree differs per platform. We keep a map of known hashes below.
  # To update: build once with `lib.fakeSha256` on each target platform and add
  # the resulting hash to the `npmDepsHash` attrset.
  piWithDeps = pkgs.stdenvNoCC.mkDerivation {
    pname = "pi-coding-agent-deps";
    inherit version;
    src = piSrc;

    nativeBuildInputs = [ pkgs.nodejs pkgs.cacert ];

    buildPhase = ''
      export HOME=$TMPDIR
      export npm_config_cache=$TMPDIR/npm-cache
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      mkdir -p $TMPDIR/pkg
      if [ -f "$src" ]; then
        # tarball (e.g. npm registry fetch)
        tar xzvf $src -C $TMPDIR/pkg
        cd $TMPDIR/pkg/package
      else
        # directory (local checkout, local build, etc.)
        cp -r "$src/" $TMPDIR/pkg/package
        chmod -R +w $TMPDIR/pkg/package
        cd $TMPDIR/pkg/package
      fi
      npm install --ignore-scripts --omit=dev
    '';

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';

    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHash = npmDepsHash;
    outputHashMode = "recursive";
  };
in

# Phase 2: wrap the Node.js runtime around the pre-built CLI bundle.
pkgs.stdenvNoCC.mkDerivation {
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
