# nix/tools.nix — Hermetic tools.dhall generator
#
# Produces a tools.dhall with Nix store paths for each enabled toolchain.
# Consumed by `continuity init-buck2 --tools-specification`.
{
  pkgs,
  lean4,
}:
{
  lean ? true,
  cxx ? true,
  haskell ? true,
  rust ? false,
  nv ? false,
  reapi ? false,
}:
let
  optional = cond: some: none:
    if cond then some else none;

  dhallNone = type: "None ${type}";

  leanSection = optional lean
    ''Some { root = "${lean4}" }''
    (dhallNone "{ root : Text }");

  cxxSection = optional cxx
    ''Some { cc = "${pkgs.stdenv.cc}/bin/cc", cxx = "${pkgs.stdenv.cc}/bin/c++" }''
    (dhallNone "{ cc : Text, cxx : Text }");

  haskellSection = optional haskell
    ''Some { ghc = "${pkgs.ghc}/bin/ghc", cabal = "${pkgs.cabal-install}/bin/cabal" }''
    (dhallNone "{ ghc : Text, cabal : Text }");

  rustSection = optional (rust && pkgs ? rustc)
    ''Some { rustc = "${pkgs.rustc}/bin/rustc", cargo = "${pkgs.cargo}/bin/cargo" }''
    (dhallNone "{ rustc : Text, cargo : Text }");

  nvSection = optional nv
    (let cuda = pkgs.cudaPackages; in
    ''Some { nvcc = "${cuda.cuda_nvcc}/bin/nvcc", cuda_root = "${cuda.cuda_cudart}" }'')
    (dhallNone "{ nvcc : Text, cuda_root : Text }");
in
pkgs.writeText "tools.dhall" ''
  -- tools.dhall — hermetic tool inventory (Nix-resolved paths)
  {
    lean = ${leanSection},
    cxx = ${cxxSection},
    haskell = ${haskellSection},
    rust = ${rustSection},
    nv = ${nvSection},
    reapi = ${dhallNone "{ endpoint : Text, instance_name : Text }"}
  }
''
