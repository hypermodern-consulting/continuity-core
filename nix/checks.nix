# nix/checks.nix — Continuity verification checks
#
# Returns an attrset of check derivations:
#   sorryAudit, axiomAudit, codecCTests, codecHaskellTests
{
  pkgs,
  src,
  continuity,
  generated,
}:
let
  axiomBudget = 7;
in
{
  sorryAudit = pkgs.runCommand "continuity-sorry-audit" {
    nativeBuildInputs = [ pkgs.ripgrep ];
  } ''
    count=$(rg -c 'sorry' -g '*.lean' ${src}/Continuity \
      | awk -F: '{s+=$2} END{print s+0}' || echo 0)
    if [ "$count" -gt 0 ]; then
      echo "FAIL: $count sorry instances found"
      rg -n 'sorry' -g '*.lean' ${src}/Continuity
      exit 1
    fi
    echo "0 sorry. clean."
    touch $out
  '';

  axiomAudit = pkgs.runCommand "continuity-axiom-audit" {
    nativeBuildInputs = [ pkgs.ripgrep ];
  } ''
    count=$(rg -c '^axiom ' -g '*.lean' ${src}/Continuity \
      | awk -F: '{s+=$2} END{print s+0}' || echo 0)
    echo "axiom count: $count (budget: ${toString axiomBudget})"
    if [ "$count" -gt ${toString axiomBudget} ]; then
      echo "FAIL: axiom count $count exceeds budget of ${toString axiomBudget}"
      exit 1
    fi
    touch $out
  '';

  codecCTests = pkgs.stdenv.mkDerivation {
    pname = "continuity-codec-c-tests";
    version = "0.1.0";
    inherit src;
    nativeBuildInputs = [ pkgs.gcc ];
    buildPhase = ''
      gcc -O2 -o codec_test test/codec_test.c
      ./codec_test
    '';
    installPhase = "touch $out";
  };

  codecHaskellTests = pkgs.stdenv.mkDerivation {
    pname = "continuity-codec-hs-tests";
    version = "0.1.0";
    inherit src;
    nativeBuildInputs = [ pkgs.ghc ];
    buildPhase = ''
      ghc -O -o hs_test test/CodecTest.hs
      ./hs_test
    '';
    installPhase = "touch $out";
  };
}
