let V = ../core/Vis.dhall

in  let Genrule = { name : Text
             , out : Text
             , cmd : Text
             , srcs : List Text
             , vis : V.Vis
             }

in  let genrule = λ(name : Text) → λ(out : Text) → λ(cmd : Text) → { name = name
             , out = out
             , cmd = cmd
             , srcs = [] : List Text
             , vis = V.public
             }

in  { Genrule = Genrule
, genrule = genrule
}
