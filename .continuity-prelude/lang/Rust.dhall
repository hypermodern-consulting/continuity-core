let D = ../core/Dep.dhall

in  let V = ../core/Vis.dhall

in  let Edition : Type = < E2015 | E2018 | E2021 | E2024 >

in  let Binary = { name : Text
            , srcs : List Text
            , deps : List D.Dep
            , edition : Edition
            , features : List Text
            , rustflags : List Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
            , srcs = srcs
            , deps = deps
            , edition = < E2015 | E2018 | E2021 | E2024 >.E2021
            , features = [] : List Text
            , rustflags = [] : List Text
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : List Text
             , deps : List D.Dep
             , edition : Edition
             , crate_name : Optional Text
             , features : List Text
             , proc_macro : Bool
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : List Text) → λ(deps : List D.Dep) → { name = name
             , srcs = srcs
             , deps = deps
             , edition = < E2015 | E2018 | E2021 | E2024 >.E2021
             , crate_name = None Text
             , features = [] : List Text
             , proc_macro = False
             , vis = V.public
             }

in  { Edition = Edition
, Binary = Binary
, binary = binary
, Library = Library
, library = library
}
