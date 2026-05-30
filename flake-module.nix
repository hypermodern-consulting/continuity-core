# flake-module.nix — Continuity generated-source module
#
# Import in any flake-parts project to get a hermetic derivation of all
# generated Continuity source.
#
# Usage:
#  {
#    inputs.continuity.url = "github:.../continuity";
#    outputs = inputs@{ flake-parts, ... }:
#      flake-parts.lib.mkFlake { inherit inputs; } {
#        imports = [ inputs.continuity.flakeModules.generated ];
#        perSystem = { config, pkgs, ... }: {
#          continuity = {
#            source = ./vendor/continuity;
#            lean4-src = inputs.lean4;
#            mimalloc-src = inputs.mimalloc;
#            leantar-src = inputs.leantar;
#          };
#          # config.continuity.generated — all generated sources (drv)
#          # config.continuity.binary     — continuity executable (drv)
#          # config.continuity.lean4      — Lean 4.30.0 (drv)
#          # config.continuity.tools-dhall — hermetic tool spec generator (fn)
#        };
#      };
#  }

{
  flake-parts-lib,
  lib,
  config,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      pkgs,
      system,
      lib,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.continuity;

      leantar-bin = pkgs.runCommand "leantar" { } ''
        mkdir -p $out/bin
        cp ${cfg.leantar-src}/leantar $out/bin/leantar
        chmod +x $out/bin/leantar
      '';

      lean4-v430 = pkgs.stdenv.mkDerivation {
        pname = "lean4";
        version = "4.30.0";
        src = cfg.lean4-src;
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
              --replace-fail 'MIMALLOC-SRC' '${cfg.mimalloc-src}'
            for file in stage0/src/CMakeLists.txt stage0/src/runtime/CMakeLists.txt src/CMakeLists.txt src/runtime/CMakeLists.txt; do
              substituteInPlace "$file" \
                --replace-fail '${mimallocIncludePattern}' '${cfg.mimalloc-src}'
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
        meta = with lib; {
          description = "Lean 4 theorem prover";
          homepage = "https://leanprover.github.io/";
          license = licenses.asl20;
          platforms = platforms.all;
          mainProgram = "lean";
        };
      };

      continuity-bin = pkgs.stdenv.mkDerivation {
        pname = "continuity";
        version = "0.1.0";
        src = cfg.source;
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

      continuity-generated =
        pkgs.runCommand "continuity-generated"
          {
            nativeBuildInputs = [ continuity-bin ];
          }
          ''
            mkdir -p $out
            continuity generate $out 2>&1
            echo ""
            echo "  files: $(find $out -type f | wc -l)"
          '';

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
    in
    {
      options.continuity = {
        source = mkOption {
          type = types.path;
          description = "Path to the Continuity source tree";
        };
        lean4-src = mkOption {
          type = types.path;
          description = "Path to lean4 v4.30.0 source";
        };
        mimalloc-src = mkOption {
          type = types.path;
          description = "Path to mimalloc source";
        };
        leantar-src = mkOption {
          type = types.path;
          description = "Path to leantar release tarball contents";
        };
        generated = mkOption {
          type = types.package;
          readOnly = true;
          description = "Derivation containing all generated Continuity source (Dhall, C++, Haskell)";
        };
        binary = mkOption {
          type = types.package;
          readOnly = true;
          description = "Continuity executable";
        };
        lean4 = mkOption {
          type = types.package;
          readOnly = true;
          description = "Lean 4.30.0 derivation";
        };
        tools-dhall = mkOption {
          type = types.raw;
          readOnly = true;
          description = "Function to generate a hermetic tools.dhall derivation";
        };
      };

      config.continuity = {
        generated = continuity-generated;
        binary = continuity-bin;
        lean4 = lean4-v430;
        tools-dhall = mkToolsDhall;
      };
    }
  );
}
