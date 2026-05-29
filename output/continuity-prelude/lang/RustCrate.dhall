let V = ../core/Vis.dhall

in  let CratesIo = { name : Text
              , version : Text
              , sha256 : Text
              , features : List Text
              , deps : List Text
              , proc_macro : Bool
              , vis : V.Vis
              }

in  let cratesIo = λ(name : Text) → λ(version : Text) → λ(sha256 : Text) → { name = name
              , version = version
              , sha256 = sha256
              , features = [] : List Text
              , deps = [] : List Text
              , proc_macro = False
              , vis = V.public
              }

in  let HttpArchive = { name : Text
                 , url : Text
                 , sha256 : Text
                 , strip_prefix : Optional Text
                 , vis : V.Vis
                 }

in  let httpArchive = λ(name : Text) → λ(url : Text) → λ(sha256 : Text) → { name = name
                 , url = url
                 , sha256 = sha256
                 , strip_prefix = None Text
                 , vis = V.public
                 }

in  { CratesIo = CratesIo
, cratesIo = cratesIo
, HttpArchive = HttpArchive
, httpArchive = httpArchive
}
