{ pkgs
, piSrc ? pkgs.fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-${version}-source.tar.gz";
    sha256 = srcHash;
  }
, version ? "0.87.1"
, srcHash ? "sha256-eTlJ2NnlZik0bku5pr9fwXlS73RqG/TzGF+Olg6Ab88="
, npmDepsHash ? {
    aarch64-darwin = "sha256-QVO552JAR2TxQ2x5hObg8VzZPmTLXUms2gypiBM1XXA=";
    x86_64-linux   = "sha256-BWJs2eNJqVnZ3ONzj4rLTpUsFecu6G6jtm7R6F44gPs=";
  }.${pkgs.stdenv.hostPlatform.system} or (throw "pi-coding-agent: no npmDepsHash known for ${pkgs.stdenv.hostPlatform.system}; build once with lib.fakeSha256 and add it here")
}:

let
  # Phase 1: fetch the monorepo source and install all dependencies (including
  # devDependencies, because we need the `tsgo` TypeScript compiler to build).
  # This is a fixed-output derivation so it is allowed to talk to the npm registry.
  #
  # Because `npm install` skips incompatible optionalDependencies, the installed
  # node_modules tree differs per platform. We keep a map of known hashes below.
  # To update: build once with `pkgs.lib.fakeSha256` on each target platform and add
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
      npm install --ignore-scripts
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

# Phase 2: build the monorepo and wrap the CLI.
pkgs.stdenvNoCC.mkDerivation {
  pname = "pi-coding-agent";
  inherit version;
  src = piSrc;

  patches = [
    ./0001-chat-viewport-responsive-layout.patch
    ./0002-retry-parse-rate-limit-headers.patch
    ./0003-ai-retry-parse-rate-limit-headers.patch
    ./0004-symlink-extension-package-root.patch
  ];

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.nodejs ];

  postPatch = ''
    # Copy pre-installed node_modules from the fixed-output derivation.
    # The source tarball is unpacked by stdenv; we just need to add the deps.
    cp -r ${piWithDeps}/node_modules node_modules
    chmod -R +w node_modules

    # Fix shebangs in npm-installed binaries (e.g. tsgo) so they work in the nix sandbox.
    patchShebangs node_modules/
  '';

  buildPhase = ''
    # Build all workspace packages in dependency order.
    # Use build:offline to avoid network calls (e.g. fetching model catalog from models.dev).
    # The root script handles ordering: chord -> tui -> telemetry -> ai -> agent -> sqlite-node -> protocol -> client -> server -> coding-agent
    npm run build:offline
  '';

  installPhase = ''
    mkdir -p $out/lib/node_modules/@earendil-works/pi-coding-agent
    cp -r packages/coding-agent/dist $out/lib/node_modules/@earendil-works/pi-coding-agent/
    cp packages/coding-agent/package.json $out/lib/node_modules/@earendil-works/pi-coding-agent/

    # The bundle chunks import workspace packages (e.g. @earendil-works/chord)
    # as bare module specifiers. Copy node_modules so Node.js can resolve them.
    # The workspace symlinks in node_modules/@earendil-works/ point to
    # ../../packages/<name>, so we also copy the packages directory.
    cp -r ${piWithDeps}/node_modules $out/lib/node_modules/@earendil-works/pi-coding-agent/
    cp -r packages $out/lib/node_modules/@earendil-works/pi-coding-agent/

    mkdir -p $out/bin
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/pi \
      --add-flags "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
  '';

  meta = {
    description = "Pi coding agent — AI-powered terminal coding assistant";
    mainProgram = "pi";
  };
}
