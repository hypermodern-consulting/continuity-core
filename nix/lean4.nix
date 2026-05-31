# nix/lean4.nix — Lean 4 from source with hermetic mimalloc
#
# Returns a derivation for Lean 4.30.0 built from the pinned source
# with mimalloc vendored from a Nix input rather than fetched at build time.
{
  pkgs,
  lean4-src,
  mimalloc-src,
  leantar-src,
}:
let
  leantar-bin = pkgs.runCommand "leantar" { } ''
    mkdir -p $out/bin
    cp ${leantar-src}/leantar $out/bin/leantar
    chmod +x $out/bin/leantar
  '';

  mimallocIncludePattern =
    "\${LEAN_BINARY_DIR}/../mimalloc/src/mimalloc";
in
pkgs.stdenv.mkDerivation {
  pname = "lean4";
  version = "4.30.0";
  src = lean4-src;

  preConfigure = ''
    patchShebangs stage0/src/bin/ src/bin/
  '';

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
    pkgs.perl
    leantar-bin
  ];

  buildInputs = [
    pkgs.gmp
    pkgs.libuv
    pkgs.cadical
  ];

  patches = [ ./patches/mimalloc-local-source.patch ];

  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'set(GIT_SHA1 "")' 'set(GIT_SHA1 "v4.30.0")'
    substituteInPlace CMakeLists.txt \
      --replace-fail 'MIMALLOC-SRC' '${mimalloc-src}'
    for file in stage0/src/CMakeLists.txt stage0/src/runtime/CMakeLists.txt \
                src/CMakeLists.txt src/runtime/CMakeLists.txt; do
      substituteInPlace "$file" \
        --replace-fail '${mimallocIncludePattern}' '${mimalloc-src}'
    done
    rm -rf src/lake/examples/git/
  '';

  cmakeFlags = [
    "-DUSE_GITHASH=OFF"
    "-DINSTALL_LICENSE=OFF"
    "-DINSTALL_CADICAL=OFF"
    "-DINSTALL_LEANTAR=OFF"
    "-DUSE_MIMALLOC=ON"
  ];

  meta = {
    description = "Lean 4 theorem prover";
    homepage = "https://leanprover.github.io/";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "lean";
  };
}
