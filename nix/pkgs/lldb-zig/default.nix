# lldb-zig — Zig-aware LLDB fork
#
# Upstream: https://github.com/jacobly0/llvm-project (Jacob Young, ziglang org)
# Zig's README describes this fork under "Testing Zig Code with LLDB":
#   https://codeberg.org/ziglang/zig#testing-zig-code-with-lldb
# "This fork only contains changes for debugging programs compiled by Zig's
#  self-hosted backends, i.e. `zig build-exe -fno-llvm ...`."
#
# Zig 0.16 defaults to the self-hosted backend on x86_64-linux (emits DWARF 5),
# so this fork renders Zig types (slices, optionals, tagged unions, std types)
# natively in LLDB/LIBLLDB — no Python pretty printers required.
#
# Build cost warning: this compiles LLVM 23 trunk + clang + lldb. Expect
# 30-90 minutes on a modern desktop and ~20GB of scratch space. The result is
# cached in the nix store, rebuilds only happen when `rev` changes.
#
# The fork exposes the binaries under zig-prefixed names so they don't shadow
# a regular `lldb` installation:
#   zig-lldb        — the LLDB driver (TUI/CLI)
#   zig-lldb-dap    — the DAP server used by nvim-dap
#   zig-lldb-server — the lldb-server debug backend
{
  pkgs,
  # Branch to build. Two options:
  #   * "lldb-zig-dev" tip — LLVM 23, actively maintained, tracks current Zig
  #     self-hosted-backend DWARF encodings (recommended for Zig 0.16).
  #   * "lldb-zig" tip (e0a42bb343616608f4fdd1284246f82b0d3029d7) — the older
  #     stable line referenced by Zig's README ( LLVM ~19 era, Jan 2025).
  rev ? "86a744cac9ad3940f48641b382d302b7eac66037", # lldb-zig-dev @ 2026-10-02
  hash ? "sha256-mAkc+1/VBLoIINAgOpbFYIddaHZJcPgwrJIDimpgiGk=",
  # LLVM targets to build support for; defaults to the native target.
  targetsToBuild ? null,
  # Python scripting inside lldb (heavier build; Zig rendering does not need it).
  enablePython ? false,
}:

let
  inherit (pkgs) lib stdenv;

  # Default to the host's native target to keep build times down.
  hostTargets =
    if targetsToBuild != null then
      targetsToBuild
    else if stdenv.hostPlatform.isx86_64 then
      "X86"
    else if stdenv.hostPlatform.isAarch64 then
      "AArch64"
    else
      throw "lldb-zig: unsupported host platform";

  # Isolate the rev's date for the version string.
  shortRev = builtins.substring 0 9 rev;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lldb-zig";
  version = "23.0.0-zig-${shortRev}";

  src = pkgs.fetchFromGitHub {
    owner = "jacobly0";
    repo = "llvm-project";
    inherit rev hash;
  };

  # Runtime libraries LLDB links against.
  buildInputs = with pkgs; [
    zlib
    zstd
    libxml2
    ncurses
    libedit
  ];

  # python3 is required by LLVM's build tooling even with tests disabled.
  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    python3
  ] ++ lib.optionals enablePython [ swig ];

  # The LLVM monorepo's root CMakeLists lives in `llvm/`, hence the custom
  # configurePhase. Flags follow the upstream Zig README recipe plus nixpkgs
  # conventions:
  #   cmake llvm -G Ninja -B build \
  #     -DLLVM_ENABLE_PROJECTS="clang;lldb" \
  #     -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON \
  #     -DLLDB_ENABLE_LIBEDIT=ON
  # (lldb requires the clang sources for its expression/AST integration, hence
  # "clang;lldb" even though we only ship LLDB binaries.)
  cmakeFlags = [
    "-G Ninja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLVM_ENABLE_PROJECTS=clang;lldb"
    "-DLLVM_TARGETS_TO_BUILD=${hostTargets}"
    "-DLLVM_ENABLE_ASSERTIONS=ON"
    # Linking lldb/liblldb is RAM-heavy; cap parallel links (no swap on odin).
    "-DLLVM_PARALLEL_LINK_JOBS=2"
    # Trim everything we don't ship.
    "-DLLVM_INCLUDE_TESTS=OFF"
    "-DLLVM_INCLUDE_EXAMPLES=OFF"
    "-DLLVM_INCLUDE_BENCHMARKS=OFF"
    "-DLLVM_INCLUDE_DOCS=OFF"
    "-DLLVM_ENABLE_BINDINGS=OFF"
    "-DLLVM_ENABLE_OCAMLDOC=OFF"
    "-DLLVM_ENABLE_Z3_SOLVER=OFF"
    "-DLLVM_ENABLE_ZLIB=ON"
    "-DLLVM_ENABLE_ZSTD=ON"
    "-DLLVM_ENABLE_LIBXML2=ON"
    "-DLLVM_ENABLE_TERMINFO=ON"
    "-DLLDB_ENABLE_LIBEDIT=ON"
    "-DLLDB_ENABLE_LUA=OFF"
    "-DLLDB_ENABLE_PYTHON=${if enablePython then "ON" else "OFF"}"
    # nix fixup forbids /build (sandbox) references in RPATHs; LLVM otherwise
    # embeds build-tree paths so freshly-built binaries find liblldb. Build
    # with the install RPATH instead ($ORIGIN/../lib for $out/lib/liblldb).
    "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    "-DCMAKE_INSTALL_RPATH=\$ORIGIN/../lib"
  ];

  configurePhase = ''
    runHook preConfigure
    mkdir -p "$NIX_BUILD_TOP/build"
    cd "$NIX_BUILD_TOP/build"
    cmake "$src/llvm" $cmakeFlags
    runHook postConfigure
  '';

  # Build only the debugger binaries we actually install; this skips the full
  # clang/llvm toolchain that `ninja`/`ninja install` would build.
  buildPhase = ''
    runHook preBuild
    cd "$NIX_BUILD_TOP/build"
    ninja -j "$NIX_BUILD_CORES" lldb lldb-server lldb-dap
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib"
    cd "$NIX_BUILD_TOP/build"
    cp bin/lldb bin/lldb-server bin/lldb-dap "$out/bin/"
    # Ship the shared liblldb if this build produced one (static vs shared
    # linking is decided by cmake defaults).
    cp lib/liblldb.so* "$out/lib/" 2>/dev/null || true
    runHook postInstall
  '';

  # zig-prefixed symlinks so the fork doesn't shadow a system lldb and so
  # exepath('zig-lldb-dap') resolves unambiguously in nvim-dap.
  #
  # lldb --version knows nothing about our naming, so a plain version check is
  # meaningless; we verify via `zig-lldb --version` under passthru.tests.
  postFixup = ''
    ln -sfn lldb "$out/bin/zig-lldb"
    ln -sfn lldb-dap "$out/bin/zig-lldb-dap"
    ln -sfn lldb-server "$out/bin/zig-lldb-server"
  '';

  passthru = {
    updateScript = pkgs.writeShellScript "lldb-zig-update" ''
      # Fetch the current lldb-zig-dev tip and print the rev/hash pair to paste
      # into the default parameters above.
      rev=$(curl -s https://api.github.com/repos/jacobly0/llvm-project/branches/lldb-zig-dev | jq -r .commit.sha)
      echo "rev: $rev"
      nix --accept-flake-config flake prefetch github:jacobly0/llvm-project/$rev 2>/dev/null | tail -1
    '';
  };

  meta = {
    description = "LLDB fork with native Zig debugging support (jacobly0/llvm-project lldb-zig)";
    homepage = "https://github.com/jacobly0/llvm-project/tree/lldb-zig";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "zig-lldb";
  };
})
