let V = ../core/Vis.dhall

in  let NixBinary = { name : Text
               , srcs : List Text
               , nix_deps : List Text
               , deps : List Text
               , compiler_flags : List Text
               , linker_flags : List Text
               , vis : V.Vis
               }

in  let nixBinary = λ(name : Text) → λ(srcs : List Text) → λ(nix_deps : List Text) → { name = name
               , srcs = srcs
               , nix_deps = nix_deps
               , deps = [] : List Text
               , compiler_flags = [] : List Text
               , linker_flags = [] : List Text
               , vis = V.public
               }

in  { NixBinary = NixBinary
, nixBinary = nixBinary
}
