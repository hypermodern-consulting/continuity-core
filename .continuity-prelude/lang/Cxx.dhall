let D = ../core/Dep.dhall

in  let V = ../core/Vis.dhall

in  let CxxStd : Type = < Cxx11 | Cxx14 | Cxx17 | Cxx20 | Cxx23 >

in  let Binary = { name : Text
            , srcs : List Text
            , deps : List D.Dep
            , std : CxxStd
            , cflags : List Text
            , ldflags : List Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
            , srcs = srcs
            , deps = deps
            , std = < Cxx11 | Cxx14 | Cxx17 | Cxx20 | Cxx23 >.Cxx17
            , cflags = [] : List Text
            , ldflags = [] : List Text
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : List Text
             , hdrs : List Text
             , deps : List D.Dep
             , std : CxxStd
             , cflags : List Text
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
             , srcs = srcs
             , deps = deps
             , hdrs = [] : List Text
             , std = < Cxx11 | Cxx14 | Cxx17 | Cxx20 | Cxx23 >.Cxx17
             , cflags = [] : List Text
             , vis = V.public
             }

in  { CxxStd = CxxStd
, Binary = Binary
, binary = binary
, Library = Library
, library = library
}
