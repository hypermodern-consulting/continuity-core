{
  description = "Continuity — Verified Metaprogramming for Secure Computation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    lean4 = {
      url = "github:leanprover/lean4/v4.30.0";
      flake = false;
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, system, ... }:
        let
          # Lake handles the Lean build; Nix provides the shell and tooling.
          # We do NOT nix-build the Lean project — that's Lake's job.
          # Nix gives us: elan, git, formatting, CI deps.
        in
        {
          devShells.default = pkgs.mkShell {
            name = "continuity";
            packages = with pkgs; [
              elan          # manages lean toolchains via lean-toolchain file
              git
              gh            # github cli
              gnumake       # for convenience targets
            ];
            shellHook = ''
              echo "continuity dev shell"
              echo "lean toolchain: $(cat lean-toolchain 2>/dev/null || echo 'not found')"
              echo ""
              echo "  lake build        — build everything"
              echo "  lake exe continuity — run the binary"
              echo ""
            '';
          };

          # Formatting: lean files don't have a standard formatter yet.
          # We enforce style by convention and review.
        };
    };
}
