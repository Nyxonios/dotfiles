{ lib, stdenv, fetchurl, undmg }:

stdenv.mkDerivation rec {
  pname = "betterdisplay";
  version = "4.3.4";

  src = fetchurl {
    url = "https://github.com/waydabber/BetterDisplay/releases/download/v${version}/BetterDisplay-v${version}.dmg";
    sha256 = "234122f7e4ec6e6b00ea2143d42c12720ad4ece3bd98bddf977feebc2612e092";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    app_path=$(find . -maxdepth 2 -name "BetterDisplay.app" -type d | head -n1)
    if [ -z "$app_path" ]; then
      echo "ERROR: BetterDisplay.app not found in extracted contents"
      ls -laR .
      exit 1
    fi
    cp -r "$app_path" $out/Applications/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Display management tool for macOS";
    homepage = "https://betterdisplay.pro/";
    license = licenses.unfree;
    platforms = platforms.darwin;
    maintainers = [ ];
  };
}
