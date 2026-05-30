{
  description = "Continuity — Verified Metaprogramming for Secure Computation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lean4 = {
      url = "github:leanprover/lean4/v4.30.0";
      flake = false;
    };
    mimalloc = {
      url = "github:microsoft/mimalloc/v2.2.3";
      flake = false;
    };
    leantar = {
      url = "https://github.com/digama0/leangz/releases/download/v0.1.19/leantar-v0.1.19-x86_64-unknown-linux-musl.tar.gz";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      treefmt-nix,
      lean4,
      mimalloc,
      leantar,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
        ./flake-module.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      flake.flakeModules.generated = ./flake-module.nix;

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          continuity = {
            source = ./.;
            lean4-src = lean4;
            mimalloc-src = mimalloc;
            leantar-src = leantar;
          };

          packages = {
            continuity = config.continuity.binary;
            continuity-generated = config.continuity.generated;
            lean4-v430 = config.continuity.lean4;
            tools-dhall = config.continuity.tools-dhall { };
            tools-dhall-cxx = config.continuity.tools-dhall { haskell = false; };
          };

          checks =
            let
              inherit (config.continuity) binary generated;
              continuity = binary;
              continuity-generated = generated;
              sorryAudit = pkgs.runCommand "continuity-sorry-audit" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
                count=$(rg -c 'sorry' -g '*.lean' ${./Continuity} | awk -F: '{s+=$2} END{print s+0}' || echo 0)
                if [ "$count" -gt 0 ]; then
                  echo "FAIL: $count sorry instances found"
                  rg -n 'sorry' -g '*.lean' ${./Continuity}
                  exit 1
                fi
                echo "0 sorry. clean."
                touch $out
              '';
              axiomAudit = pkgs.runCommand "continuity-axiom-audit" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
                count=$(rg -c '^axiom ' -g '*.lean' ${./Continuity} | awk -F: '{s+=$2} END{print s+0}' || echo 0)
                echo "axiom count: $count (budget: 7)"
                if [ "$count" -gt 7 ]; then
                  echo "FAIL: axiom count $count exceeds budget of 7"
                  exit 1
                fi
                touch $out
              '';
              codecCTests = pkgs.stdenv.mkDerivation {
                pname = "continuity-codec-c-tests";
                version = "0.1.0";
                src = ./.;
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
                src = ./.;
                nativeBuildInputs = [ pkgs.ghc ];
                buildPhase = ''
                  ghc -O -o hs_test test/CodecTest.hs
                  ./hs_test
                '';
                installPhase = "touch $out";
              };
            in
            {
              inherit
                continuity
                continuity-generated
                sorryAudit
                axiomAudit
                codecCTests
                codecHaskellTests
                ;
            };

          treefmt = {
            projectRootFile = "lakefile.lean";
            programs = {
              nixfmt.enable = true;
              clang-format.enable = true;
              fourmolu.enable = true;
              buildifier.enable = true;
              dhall.enable = true;
            };
            settings = {
              global.excludes = [
                ".continuity-prelude/*"
                "buck-out/*"
                ".lake/*"
                "output/*"
                "result/*"
              ];
              formatter = {
                clang-format.includes = [
                  "*.c"
                  "*.h"
                  "*.hpp"
                  "*.cpp"
                  "*.cc"
                  "*.cxx"
                ];
                fourmolu.includes = [ "*.hs" ];
                buildifier.includes = [
                  "*.bzl"
                  "BUCK"
                ];
                dhall.includes = [ "*.dhall" ];
              };
            };
          };

          devShells.default = pkgs.mkShell {
            name = "continuity";
            packages = with pkgs; [
              config.continuity.lean4
              cadical
              gcc
              ghc
              cabal-install
              buck2
              ripgrep
              git
              gh
              gnumake
              python3
            ];
            shellHook = ''
              echo "continuity — verified metaprogramming"
              echo ""
              echo "  nix build .#                    — build continuity binary"
              echo "  nix build .#continuity-generated — all generated sources"
              echo "  nix build .#tools-dhall          — hermetic tools.dhall"
              echo "  nix flake check                  — all checks (sorry audit, C + Haskell tests)"
              echo "  nix run .# -- <args>             — run continuity"
              echo ""
            '';
          };

          apps = {
            continuity = {
              type = "app";
              program = "${config.continuity.binary}/bin/continuity";
              meta.description = "Verified metaprogramming platform";
            };
            init-buck2 =
              let
                script = pkgs.writeShellScriptBin "continuity-init-buck2" ''
                  set -euo pipefail
                  SPEC=""
                  TARGET="."
                  while [ $# -gt 0 ]; do
                    case "$1" in
                      --tools-spec) SPEC="$2"; shift 2 ;;
                      --tools-spec=*) SPEC="''${1#--tools-spec=}"; shift ;;
                      *) TARGET="$1"; shift ;;
                    esac
                  done
                  if [ -z "$SPEC" ]; then
                    echo "Usage: nix run .#init-buck2 -- --tools-spec tools.dhall [target-dir]" >&2
                    echo "       nix run .#init-buck2 -- --tools-spec \$(nix build .#tools-dhall --no-link --print-out-paths)" >&2
                    exit 1
                  fi
                  exec ${config.continuity.binary}/bin/continuity init-buck2 --tools-specification="$SPEC" "$TARGET"
                '';
              in
              {
                type = "app";
                program = "${script}/bin/continuity-init-buck2";
              };
          };
        };
    };
}
