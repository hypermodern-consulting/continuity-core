# nix/default.nix — Continuity flake-parts module
#
# Consumer usage:
#
#   {
#     inputs.continuity.url = "github:hypermodern-consulting/continuity-core";
#
#     outputs = inputs@{ flake-parts, ... }:
#       flake-parts.lib.mkFlake { inherit inputs; } {
#         imports = [ inputs.continuity.flakeModules.default ];
#         perSystem = { config, ... }: {
#           continuity.toolchains = {
#             lean = true;
#             cxx = true;
#             haskell = true;
#           };
#           # config.continuity.binary     — continuity executable
#           # config.continuity.generated  — all generated sources
#           # config.continuity.buckconfig — .buckconfig.local with store paths
#           # config.continuity.devShell   — nix develop with everything on PATH
#         };
#       };
#   }

# Closed over by the defining flake. Consumers never see these.
{ lean4-src, mimalloc-src, leantar-src, continuity-src }:

# Standard flake-parts module API.
{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, lib, ... }:
    let
      inherit (lib) mkOption mkEnableOption types;
      cfg = config.continuity;

      lean4 = import ./lean4.nix {
        inherit pkgs lean4-src mimalloc-src leantar-src;
      };

      continuity = import ./continuity.nix {
        inherit pkgs lean4;
        src = continuity-src;
      };

      generated = import ./generated.nix {
        inherit pkgs continuity;
      };

      checks = import ./checks.nix {
        inherit pkgs continuity generated;
        src = continuity-src;
      };

      resolvedTools = import ./tools.nix { inherit pkgs lean4; } {
        lean    = cfg.toolchains.lean;
        cxx     = cfg.toolchains.cxx;
        haskell = cfg.toolchains.haskell;
        rust    = cfg.toolchains.rust;
        nv      = cfg.toolchains.cuda;
      };

      buckconfig = import ./buckconfig.nix {
        inherit pkgs lib lean4;
        toolchains = cfg.toolchains;
        libraries = cfg.libraries;
      };

      # GHC with packages from library spec (same one buckconfig uses)
      ghcWithLibs = if cfg.libraries.haskell == [] then pkgs.ghc
        else pkgs.haskellPackages.ghcWithPackages (ps:
          map (name: ps.${name}) cfg.libraries.haskell);

      toolchainPackages = lib.concatLists [
        (lib.optional cfg.toolchains.lean       lean4)
        (lib.optionals cfg.toolchains.cxx [
          pkgs.llvmPackages_19.clang
          pkgs.llvmPackages_19.lld
          pkgs.gcc  # still needed for libstdc++
        ])
        (lib.optional cfg.toolchains.haskell    ghcWithLibs)
        (lib.optional cfg.toolchains.haskell    pkgs.cabal-install)
        (lib.optional cfg.toolchains.rust       pkgs.rustc)
        (lib.optional cfg.toolchains.rust       pkgs.cargo)
        (lib.optional cfg.toolchains.python     pkgs.python3)
        (lib.optional cfg.toolchains.purescript pkgs.purescript)
        (lib.optional cfg.toolchains.purescript pkgs.spago)
        (lib.optional cfg.toolchains.purescript pkgs.nodejs)
        (lib.optionals cfg.toolchains.cuda [
          pkgs.cudaPackages.cuda_nvcc
          pkgs.cudaPackages.cuda_cudart
        ])
      ];
    in
    {
      options.continuity = {
        toolchains = {
          lean       = mkEnableOption "Lean 4 toolchain";
          cxx        = mkEnableOption "C/C++ toolchain";
          haskell    = mkEnableOption "Haskell toolchain (GHC + Cabal)";
          rust       = mkEnableOption "Rust toolchain";
          cuda       = mkEnableOption "NVIDIA CUDA toolchain";
          python     = mkEnableOption "Python toolchain";
          purescript = mkEnableOption "PureScript toolchain";
          reapi = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                endpoint = mkOption { type = types.str; };
                instance_name = mkOption {
                  type = types.str;
                  default = "default";
                };
              };
            });
            default = null;
            description = "Remote execution API configuration.";
          };
        };

        libraries = {
          haskell = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Haskell packages to include in ghcWithPackages.";
            example = [ "aeson" "text" "bytestring" "crypton" ];
          };
          cxx = mkOption {
            type = types.listOf (types.submodule {
              options = {
                name = mkOption { type = types.str; description = "Target name in //third-party:name"; };
                pkg  = mkOption { type = types.str; description = "nixpkgs attribute name"; };
                libs = mkOption { type = types.listOf types.str; default = []; description = "Link flags"; };
              };
            });
            default = [];
            description = "C/C++ libraries resolved from nixpkgs.";
            example = [
              { name = "curl"; pkg = "curl"; libs = ["-lcurl"]; }
            ];
          };
        };

        tools = mkOption {
          type = types.package;
          default = resolvedTools;
          description = ''
            tools.dhall with Nix store paths. Override for custom layouts.
          '';
        };

        buckconfig = mkOption {
          type = types.package;
          default = buckconfig;
          description = ''
            .buckconfig.local with Nix store paths for all enabled toolchains.
            Symlink into your project: ln -sf $(nix build .#buckconfig --print-out-paths) .buckconfig.local
          '';
        };

        lean4 = mkOption {
          type = types.package;
          readOnly = true;
          default = lean4;
          description = "Lean 4.30.0 derivation.";
        };
        binary = mkOption {
          type = types.package;
          readOnly = true;
          default = continuity;
          description = "Continuity executable.";
        };
        generated = mkOption {
          type = types.package;
          readOnly = true;
          default = generated;
          description = "All generated sources (Dhall, C++, Haskell).";
        };
        checks = mkOption {
          type = types.attrsOf types.package;
          readOnly = true;
          default = checks;
          description = "Verification checks.";
        };
        devShell = mkOption {
          type = types.package;
          readOnly = true;
          default = pkgs.mkShell {
            name = "continuity";
            packages = toolchainPackages ++ [
              continuity
              pkgs.buck2
              pkgs.cadical
              pkgs.ripgrep
              pkgs.git
              pkgs.gnumake
            ];
            shellHook = ''
              if [ -f lakefile.lean ] || [ -f BUCK ]; then
                ln -sf ${buckconfig} .buckconfig.local
              fi
            '';
          };
          description = "Development shell with all enabled toolchains.";
        };
      };
    }
  );
}
