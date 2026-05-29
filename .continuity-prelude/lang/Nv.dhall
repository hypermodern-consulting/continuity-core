let D = ../core/Dep.dhall

in  let V = ../core/Vis.dhall

in  let Binary = { name : Text
            , srcs : List Text
            , deps : List D.Dep
            , archs : List Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : List Text) → { name = name
            , srcs = srcs
            , deps = [] : List (List D.Dep)
            , archs = [] : List Text
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : List Text
             , exported_headers : List Text
             , deps : List D.Dep
             , archs : List Text
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : List Text) → { name = name
             , srcs = srcs
             , exported_headers = [] : List Text
             , deps = [] : List (List D.Dep)
             , archs = [] : List Text
             , vis = V.public
             }

in  { Binary = Binary
, binary = binary
, Library = Library
, library = library
}
