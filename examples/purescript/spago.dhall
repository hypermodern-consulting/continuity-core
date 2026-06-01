{ name = "halogen-todo"
, dependencies =
    [ "aff"
    , "arrays"
    , "console"
    , "effect"
    , "foldable-traversable"
    , "halogen"
    , "halogen-vdom"
    , "maybe"
    , "prelude"
    , "strings"
    , "web-dom"
    , "web-html"
    ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
