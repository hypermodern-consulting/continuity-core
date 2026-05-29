let Triple = ./core/Triple.dhall

in  let Dep = ./core/Dep.dhall

in  let Vis = ./core/Vis.dhall

in  let Res = ./core/Resource.dhall

in  let TC = ./build/Toolchain.dhall

in  let Cxx = ./lang/Cxx.dhall

in  let Hs = ./lang/Haskell.dhall

in  let Rs = ./lang/Rust.dhall

in  let Ln = ./lang/Lean.dhall

in  let Nv = ./lang/Nv.dhall

in  let PS = ./lang/PureScript.dhall

in  let Gen = ./lang/Genrule.dhall

in  let NC = ./lang/NixCxx.dhall

in  let RC = ./lang/RustCrate.dhall

in  let Rule = ./build/Rule.dhall

in  { Triple = Triple
, Dep = Dep.Dep
, dep = Dep
, vis = Vis
, resource = Res
, toolchain = TC
, lang = { Cxx = Cxx
  , Haskell = Hs
  , Rust = Rs
  , Lean = Ln
  , Nv = Nv
  , PureScript = PS
  , Genrule = Gen
  , NixCxx = NC
  , RustCrate = RC
  }
, rule = Rule
}
