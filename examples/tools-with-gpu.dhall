-- tools-with-gpu.dhall — for machines with NVIDIA SDK
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
  nv    = Some {
    nvcc = "/usr/local/cuda/bin/nvcc",
    cuda_root = "/usr/local/cuda"
  },
  reapi = None { endpoint : Text, instance_name : Text }
}
