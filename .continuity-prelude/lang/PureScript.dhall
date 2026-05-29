let V = ../core/Vis.dhall

in  let SrcSpec : Type = < Explicit : List Text | Glob : Text | Globs : List Text >

in  let App = { name : Text
         , srcs : SrcSpec
         , spago_yaml : Text
         , spago_lock : Optional Text
         , main : Text
         , index_html : Optional Text
         , style_css : Optional Text
         , vis : V.Vis
         }

in  let app = λ(name : Text) → λ(srcs : SrcSpec) → λ(spago_yaml : Text) → { name = name
         , srcs = srcs
         , spago_yaml = spago_yaml
         , spago_lock = None Text
         , main = "Main"
         , index_html = Some "index.html"
         , style_css = Some "style.css"
         , vis = V.public
         }

in  let Binary = { name : Text
            , srcs : SrcSpec
            , spago_yaml : Text
            , main : Text
            , vis : V.Vis
            }

in  let binary = λ(name : Text) → λ(srcs : SrcSpec) → λ(spago_yaml : Text) → { name = name
            , srcs = srcs
            , spago_yaml = spago_yaml
            , main = "Main"
            , vis = V.public
            }

in  let Library = { name : Text
             , srcs : SrcSpec
             , spago_yaml : Optional Text
             , vis : V.Vis
             }

in  let library = λ(name : Text) → λ(srcs : SrcSpec) → { name = name
             , srcs = srcs
             , spago_yaml = None Text
             , vis = V.public
             }

in  { App = App
, app = app
, Binary = Binary
, binary = binary
, Library = Library
, library = library
, SrcSpec = SrcSpec
}
