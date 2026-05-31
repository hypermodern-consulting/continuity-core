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
#           # config.continuity.binary    — continuity executable
#           # config.continuity.generated — all generated sources
#           # config.continuity.lean4     — Lean 4.30.0 derivation
#           # config.continuity.tools     — resolved tools.dhall
#         };
#       };
#   }

# First argument: closed over by the flake that defines this module.
# Consumers never see these — they're baked in at module definition time.
{ lean4-src, mimalloc-src, leantar-src, continuity-src }:

# Second argument: standard flake-parts module API.
{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, pkgs, lib, ... }:
    let
      inherit (lib) mkOption mkEnableOption types mkIf mkDefault;
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

      # Generate tools.dhall from toolchains config
      resolvedTools = import ./tools.nix { inherit pkgs lean4; } {
        lean    = cfg.toolchains.lean;
        cxx     = cfg.toolchains.cxx;
        haskell = cfg.toolchains.haskell;
        rust    = cfg.toolchains.rust;
        nv      = cfg.toolchains.cuda;
      };

      # Toolchain packages for devShell, conditional on what's enabled
      toolchainPackages = lib.concatLists [
        (lib.optional cfg.toolchains.lean    lean4)
        (lib.optional cfg.toolchains.cxx     pkgs.gcc)
        (lib.optional cfg.toolchains.haskell pkgs.ghc)
        (lib.optional cfg.toolchains.haskell pkgs.cabal-install)
        (lib.optional cfg.toolchains.rust    pkgs.rustc)
        (lib.optional cfg.toolchains.rust    pkgs.cargo)
        (lib.optionals cfg.toolchains.cuda [
          pkgs.cudaPackages.cuda_nvcc
          pkgs.cudaPackages.cuda_cudart
        ])
      ];
    in
    {
      options.continuity = {
        toolchains = {
          lean    = mkEnableOption "Lean 4 toolchain";
          cxx     = mkEnableOption "C/C++ toolchain";
          haskell = mkEnableOption "Haskell toolchain (GHC + Cabal)";
          rust    = mkEnableOption "Rust toolchain";
          cuda    = mkEnableOption "NVIDIA CUDA toolchain";
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

        tools = mkOption {
          type = types.package;
          default = resolvedTools;
          description = ''
            Path to tools.dhall. Defaults to a Nix-generated file with
            store paths derived from enabled toolchains. Override for
            custom toolchain layouts.
          '';
        };

        # Read-only outputs
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
          };
          description = "Development shell with all enabled toolchains.";
        };
      };
    }
  );
}
