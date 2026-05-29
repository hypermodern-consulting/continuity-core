let D = ../core/Dep.dhall

in  let V = ../core/Vis.dhall

in  let Binary = { name : Text
            , srcs : List Text
            , deps : List D.Dep
            , main : Text
            , ghcFlags : List Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
            , srcs = srcs
            , deps = deps
            , main = "Main"
            , ghcFlags = [] : List Text
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : List Text
             , deps : List D.Dep
             , modules : List Text
             , ghcFlags : List Text
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
             , srcs = srcs
             , deps = deps
             , modules = [] : List Text
             , ghcFlags = [] : List Text
             , vis = V.public
             }

in  let FFIBinary = { name : Text
               , srcs : List Text
               , cSrcs : List Text
               , deps : List D.Dep
               , main : Text
               , ghcFlags : List Text
               , cFlags : List Text
               , ldFlags : List Text
               , vis : V.Vis
               }

in  let ffiBinary = λ(name : Text) → λ(srcs : List Text) → λ(cSrcs : List Text) → λ(deps : List D.Dep) → { name = name
               , srcs = srcs
               , cSrcs = cSrcs
               , deps = deps
               , main = "Main"
               , ghcFlags = [] : List Text
               , cFlags = [] : List Text
               , ldFlags = [] : List Text
               , vis = V.public
               }

in  { Binary = Binary
, binary = binary
, Library = Library
, library = library
, FFIBinary = FFIBinary
, ffiBinary = ffiBinary
}
