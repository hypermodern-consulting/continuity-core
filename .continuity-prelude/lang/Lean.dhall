let D = ../core/Dep.dhall

in  let V = ../core/Vis.dhall

in  let Binary = { name : Text
            , srcs : List Text
            , deps : List D.Dep
            , root : Text
            , leanFlags : List Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
            , srcs = srcs
            , deps = deps
            , root = "Main.lean"
            , leanFlags = [] : List Text
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : List Text
             , deps : List D.Dep
             , root : Text
             , leanFlags : List Text
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
             , srcs = srcs
             , deps = deps
             , root = "lib.lean"
             , leanFlags = [] : List Text
             , vis = V.public
             }

in  { Binary = Binary
, binary = binary
, Library = Library
, library = library
}
