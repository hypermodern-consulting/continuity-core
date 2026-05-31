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

  outputs = inputs@{ self, flake-parts, ... }:
    let
      # Close over our inputs so downstream consumers never see them.
      continuityModule = import ./nix/default.nix {
        lean4-src = inputs.lean4;
        mimalloc-src = inputs.mimalloc;
        leantar-src = inputs.leantar;
        continuity-src = ./.;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      imports = [
        inputs.treefmt-nix.flakeModule
        continuityModule
      ];

      # Downstream consumers import this. Inputs are baked in.
      flake.flakeModules.default = continuityModule;

      # ── This repo's own configuration ──────────────────────────────

      perSystem = { config, pkgs, ... }: {
        continuity.toolchains = {
          lean = true;
          cxx = true;
          haskell = true;
        };

        packages = {
          default = config.continuity.binary;
          inherit (config.continuity) binary generated lean4 buckconfig;
          tools-dhall = config.continuity.tools;
        };

        checks =
          { inherit (config.continuity) binary generated; }
          // config.continuity.checks;

        devShells.default = config.continuity.devShell;

        apps.default = {
          type = "app";
          program = "${config.continuity.binary}/bin/continuity";
        };

        apps.init-buck2 = let
          script = pkgs.writeShellScriptBin "continuity-init-buck2" ''
            set -euo pipefail
            exec ${config.continuity.binary}/bin/continuity init-buck2 \
              --tools-specification="${config.continuity.tools}" "$@"
          '';
        in {
          type = "app";
          program = "${script}/bin/continuity-init-buck2";
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
              ".continuity-prelude/*" "buck-out/*" ".lake/*" "output/*" "result/*"
            ];
            formatter = {
              clang-format.includes = [ "*.c" "*.h" "*.hpp" "*.cpp" "*.cc" "*.cxx" ];
              fourmolu.includes = [ "*.hs" ];
              buildifier.includes = [ "*.bzl" "BUCK" ];
              dhall.includes = [ "*.dhall" ];
            };
          };
        };
      };
    };
}
