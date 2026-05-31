# nix/generated.nix — Continuity generated sources
#
# Runs `continuity generate` to produce Dhall, C++, and Haskell
# prelude sources as a single hermetic derivation.
{
  pkgs,
  continuity,
}:
pkgs.runCommand "continuity-generated" {
  nativeBuildInputs = [ continuity ];
} ''
  mkdir -p $out
  continuity generate $out 2>&1
  echo ""
  echo "  files: $(find $out -type f | wc -l)"
''
