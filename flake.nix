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
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          # ── CUDA toolchain (unfree) ──
          # Requires nixpkgs.config.allowUnfree = true in the flake config
          cuda = pkgs.cudaPackages;
          # ── Extract leantar binary from release tarball ──
          # Lean's cmake tries to download this at build time. We pre-fetch it.
          leantar-bin = pkgs.runCommand "leantar" { } ''
            mkdir -p $out/bin
            cp ${leantar}/leantar $out/bin/leantar
            chmod +x $out/bin/leantar
          '';

          # ── Lean 4.30.0 built from source ──
          # Nix derivation matching nixpkgs build strategy but pinned to v4.30.0.
          lean4-v430 = pkgs.stdenv.mkDerivation {
            pname = "lean4";
            version = "4.30.0";

            src = lean4;

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

            patches = [
              # Replace ExternalProject_Add(GIT_REPOSITORY ...) with SOURCE_DIR
              # so mimalloc is compiled from the vendored flake input, not fetched
              # from the internet during the build.
              (pkgs.writeText "mimalloc.patch" ''
                --- a/CMakeLists.txt
                +++ b/CMakeLists.txt
                @@ -80,11 +80,7 @@
                   ExternalProject_add(
                     mimalloc
                     PREFIX mimalloc
                -    GIT_REPOSITORY https://github.com/microsoft/mimalloc
                -    GIT_TAG v2.2.3
                -    # just download, we compile it as part of each stage as it is small
                -    CONFIGURE_COMMAND ""
                -    BUILD_COMMAND ""
                +    SOURCE_DIR "MIMALLOC-SRC"
                     INSTALL_COMMAND ""
                   )
                   list(APPEND EXTRA_DEPENDS mimalloc)
              '')
            ];

            postPatch =
              let
                mimallocIncludePattern = "\${LEAN_BINARY_DIR}/../mimalloc/src/mimalloc";
              in
              ''
                substituteInPlace src/CMakeLists.txt \
                  --replace-fail 'set(GIT_SHA1 "")' 'set(GIT_SHA1 "v4.30.0")'

                substituteInPlace CMakeLists.txt \
                  --replace-fail 'MIMALLOC-SRC' '${mimalloc}'

                for file in stage0/src/CMakeLists.txt stage0/src/runtime/CMakeLists.txt src/CMakeLists.txt src/runtime/CMakeLists.txt; do
                  substituteInPlace "$file" \
                    --replace-fail '${mimallocIncludePattern}' '${mimalloc}'
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

            meta = with pkgs.lib; {
              description = "Lean 4 theorem prover";
              homepage = "https://leanprover.github.io/";
              license = licenses.asl20;
              platforms = platforms.all;
              mainProgram = "lean";
            };
          };

          # ── continuity binary ──
          # Lake bootstraps continuity. The Thompson step — verified once,
          # cached thereafter.
          continuity = pkgs.stdenv.mkDerivation {
            pname = "continuity";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [
              lean4-v430
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
                --prefix PATH : ${lean4-v430}/bin
            '';
            meta.mainProgram = "continuity";
          };

          # ── generated code: Dhall prelude + C++ headers + Haskell modules ──
          # Runs `continuity generate` to produce the full codec and build
          # prelude output: 19 Dhall + 13 C++ + 13 Haskell = 45 files.
          continuity-generated =
            pkgs.runCommand "continuity-generated"
              {
                nativeBuildInputs = [ continuity ];
              }
              ''
                mkdir -p $out
                continuity generate $out 2>&1
                echo ""
                echo "  files: $(find $out -type f | wc -l)"
              '';

          # ── tools.dhall: hermetic tool path spec ──
          # Generated from nixpkgs-resolved paths. Drop-in replacement for
          # the hand-written tools.dhall in examples/.
          mkToolsDhall =
            {
              lean ? true,
              cxx ? true,
              haskell ? true,
              rust ? false,
              nv ? false,
              reapi ? false,
            }:
            let
              leanRoot = "${lean4-v430}";
            in
            pkgs.writeText "tools.dhall" ''
              -- tools.dhall — hermetic tool inventory (Nix-resolved paths)
              -- Generated by: nix build .#tools-dhall
              -- Usage: continuity init-buck2 --tools-specification=$out <target-dir>
              {
                lean = ${if lean then ''Some { root = "${leanRoot}" }'' else "None { root : Text }"},
                cxx = ${
                  if cxx then
                    ''Some { cc = "${pkgs.stdenv.cc}/bin/cc", cxx = "${pkgs.stdenv.cc}/bin/c++" }''
                  else
                    "None { cc : Text, cxx : Text }"
                },
                haskell = ${
                  if haskell then
                    ''Some { ghc = "${pkgs.ghc}/bin/ghc", cabal = "${pkgs.cabal-install}/bin/cabal" }''
                  else
                    "None { ghc : Text, cabal : Text }"
                },
                rust = ${
                  if rust && pkgs ? rustc then
                    ''Some { rustc = "${pkgs.rustc}/bin/rustc", cargo = "${pkgs.cargo}/bin/cargo" }''
                  else
                    "None { rustc : Text, cargo : Text }"
                },
                nv = ${
                  if nv then
                    let
                      cuda = pkgs.cudaPackages;
                    in
                    ''Some { nvcc = "${cuda.cuda_nvcc}/bin/nvcc", cuda_root = "${cuda.cuda_cudart}" }''
                  else
                    "None { nvcc : Text, cuda_root : Text }"
                },
                reapi = None { endpoint : Text, instance_name : Text }
              }
            '';

          # ── sorry audit ──
          sorryAudit = pkgs.runCommand "continuity-sorry-audit" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
            count=$(rg -c 'sorry' -g '*.lean' ${./Continuity} || echo 0)
            if [ "$count" -gt 0 ]; then
              echo "FAIL: $count sorry instances found"
              rg -n 'sorry' -g '*.lean' ${./Continuity}
              exit 1
            fi
            echo "0 sorry. clean."
            touch $out
          '';
          # ── axiom audit ──
          axiomAudit = pkgs.runCommand "continuity-axiom-audit" { nativeBuildInputs = [ pkgs.ripgrep ]; } ''
            count=$(rg -c '^axiom ' -g '*.lean' ${./Continuity} || echo 0)
            echo "axiom count: $count (budget: 7)"
            if [ "$count" -gt 7 ]; then
              echo "FAIL: axiom count $count exceeds budget of 7"
              exit 1
            fi
            touch $out
          '';
          # ── C property tests ──
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

          # ── Haskell property tests ──
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
          packages = {
            continuity = continuity;
            continuity-generated = continuity-generated;
            lean4-v430 = lean4-v430;
            tools-dhall = mkToolsDhall { };
            tools-dhall-cxx = mkToolsDhall { haskell = false; };
          };

          checks = {
            inherit
              continuity
              continuity-generated
              sorryAudit
              axiomAudit
              codecCTests
              codecHaskellTests
              ;
          };

          # ── formatting ──
          # `nix fmt` auto-formats all supported file types.
          # Lean has no standard formatter yet; nix, C, Haskell, Starlark, Dhall covered.
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
              lean4-v430
              gcc
              ghc
              cabal-install
              buck2
              ripgrep
              git
              gh
              gnumake
              python3
              cuda.cuda_nvcc
              cuda.cuda_cudart
            ];
            shellHook = ''
              echo "continuity — verified metaprogramming"
              echo ""
              echo "  nix build .#               — build continuity binary"
              echo "  nix build .#tools-dhall     — hermetic tools.dhall"
              echo "  nix flake check             — all checks (sorry audit, C + Haskell tests)"
              echo "  nix run .# -- <args>        — run continuity"
              echo "  nix run .#init-buck2 -- --tools-spec ..."
              echo ""
              echo "  lake build                  — bootstrap (also done by nix build)"
              echo "  buck2 build //...           — buck2-native build"
              echo ""
            '';
          };

          apps = {
            continuity = {
              type = "app";
              program = "${config.packages.continuity}/bin/continuity";
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
                  exec ${config.packages.continuity}/bin/continuity init-buck2 --tools-specification="$SPEC" "$TARGET"
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
