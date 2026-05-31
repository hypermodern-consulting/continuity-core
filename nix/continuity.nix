# nix/continuity.nix — Continuity binary
#
# Builds the continuity executable from source using Lake.
{
  pkgs,
  lean4,
  src,
}:
pkgs.stdenv.mkDerivation {
  pname = "continuity";
  version = "0.1.0";
  inherit src;

  nativeBuildInputs = [
    lean4
    pkgs.cadical
    pkgs.makeWrapper
  ];

  buildPhase = ''
    lake build continuity 2>&1
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp .lake/build/bin/continuity $out/bin/continuity
    chmod +x $out/bin/continuity
    wrapProgram $out/bin/continuity \
      --prefix PATH : ${lean4}/bin
  '';

  meta.mainProgram = "continuity";
}
