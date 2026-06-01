# nix/generated.nix — Continuity generated sources
#
# Builds all codegen output via `lake exe continuity generate $out`.
# The derivation produces a directory containing:
#
#   prelude/*.dhall         — Dhall type definitions (Triple, Dep, Vis, Resource,
#                             Library, Toolchain, Cxx, Haskell, Rust, Lean, Nv,
#                             PureScript, Genrule, NixCxx, RustCrate, Rule, package,
#                             Prelude, Coeffect, Attestation)
#   codec/*.hpp             — C++ wire-format codecs (parse/serialize pairs)
#   codec/*.hs              — Haskell wire-format codecs
#   primitive/*.hpp         — C++ protocol primitives header
#   grade/*.hpp             — C++ grade label enum + GradedResult template
#   grade/*.hs              — Haskell graded effect monad module
#   state_machine/*.h       — C++ state machine headers (5 machines)
#   toolchains/*.bzl        — Starlark build rule definitions
#   render/buck2/*.dhall    — Buck2-specific rule type definitions
#   BUCK                    — Buck2 root build file
#   MANIFEST.sha256         — Reflective hash h₁ = SHA256(LP-framed all files)
#   attestation.dhall       — Build attestation (declared grade, discharge evidence)
#
# The reflective hash h₁ is computed during generation and written to
# MANIFEST.sha256. Re-running `continuity generate` produces the same h₁
# (same files, same hash) — this is the reproducibility contract.
#
# Verification: `nix build .#generated` runs this derivation and can be
# cross-checked via `lake exe continuity generate /tmp/out && diff -r /tmp/out $(nix build --print-out-paths .#generated)`
{
  pkgs,
  continuity,
}:
pkgs.runCommand "continuity-generated"
  {
    nativeBuildInputs = [ continuity ];
    meta = {
      description = "All generated sources (Dhall, C++, Haskell, Starlark) with reflective hash";
    };
  }
  ''
    mkdir -p $out
    continuity generate $out 2>&1

    echo ""
    echo "=== generated output manifest ==="
    echo "  prelude dhall files:  $(find $out -name '*.dhall' -path '*/core/*' -o -name '*.dhall' -path '*/build/*' -o -name '*.dhall' -path '*/lang/*' -o -name '*.dhall' -path '*/render/*' | wc -l)"
    echo "  attestation:          $([ -f "$out/attestation.dhall" ] && echo yes || echo NO)"
    echo "  codec hpp files:      $(find $out/codec -name '*.hpp' 2>/dev/null | wc -l)"
    echo "  codec hs files:       $(find $out/codec -name '*.hs' 2>/dev/null | wc -l)"
    echo "  state machine files:  $(find $out/state_machine -name '*.h' 2>/dev/null | wc -l)"
    echo "  grade hpp files:      $(find $out/grade -name '*.hpp' 2>/dev/null | wc -l)"
    echo "  grade hs files:       $(find $out/grade -name '*.hs' 2>/dev/null | wc -l)"
    echo "  toolchain bzl files:  $(find $out/toolchains -name '*.bzl' 2>/dev/null | wc -l)"
    echo "  MANIFEST.sha256:      $([ -f "$out/MANIFEST.sha256" ] && echo yes || echo NO)"
    echo "  total files:          $(find $out -type f | wc -l)"
    echo "=== reflective hash ==="
    cat "$out/MANIFEST.sha256"
  ''
