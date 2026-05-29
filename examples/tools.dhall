-- tools.dhall — local tool inventory for buck2 scaffolding
-- continuity init-buck2 --tools-specification=tools.dhall
{
  lean = Some {
    root = "/root/.elan/toolchains/leanprover--lean4---v4.30.0"
  },
  cxx = Some {
    cc  = "/usr/bin/gcc",
    cxx = "/usr/bin/g++"
  },
  haskell = Some {
    ghc   = "/usr/bin/ghc",
    cabal = "/usr/bin/cabal"
  },
  rust  = None { rustc : Text, cargo : Text },
  nv    = None { nvcc : Text, cuda_root : Text },
  reapi = None { endpoint : Text, instance_name : Text }
}
