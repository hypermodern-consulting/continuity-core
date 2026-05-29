let Dep : Type = < Local : Text | Flake : Text | External : { hash : Text
         , name : Text
         } | PkgConfig : Text >

in  let local = Dep.Local

in  let flake = Dep.Flake

in  let pkgconfig = Dep.PkgConfig

in  let external = λ(hash : Text) → λ(name : Text) → Dep.External { hash = hash
              , name = name
              }

in  let nix = λ(p : Text) → Dep.Flake "nixpkgs#${p}"

in  { Dep = Dep
, local = local
, flake = flake
, external = external
, pkgconfig = pkgconfig
, nix = nix
}
