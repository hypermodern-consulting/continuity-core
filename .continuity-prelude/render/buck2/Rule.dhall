let AttrType : Type = < String : { default : Optional Text
              } | StringList : {} | Bool : { default : Bool
              } | Int : { default : Natural
              } | Dep : {} | DepDefault : { default : Text
              } | DepList : {} | Source : {} | SourceList : {} | OptionSource : {} | OptionString : {} | Output : {} | Label : {} | StringDict : {} >

in  let Attr = { name : Text
          , type : AttrType
          , doc : Text
          }

in  let Load = { bzl : Text
          , symbols : List Text
          }

in  let ProviderField : Type = < Typed : { name : Text
                   , type : Text
                   , default : Optional Text
                   } | Simple : Text >

in  let ProviderDef = { name : Text
                 , fields : List ProviderField
                 }

in  let HelperFn = { name : Text
              , params : List Text
              , returnType : Optional Text
              , body : Text
              }

in  let RuleImpl = { name : Text
              , doc : Text
              , body : Text
              , is_toolchain : Bool
              }

in  let BzlFile = { header : Text
             , loads : List Load
             , globals : Text
             , providers : List ProviderDef
             , helpers : List HelperFn
             , rules : List { impl : RuleImpl
             , attrs : List Attr
             }
             }

in  { AttrType = AttrType
, Attr = Attr
, Load = Load
, ProviderDef = ProviderDef
, ProviderField = ProviderField
, HelperFn = HelperFn
, RuleImpl = RuleImpl
, BzlFile = BzlFile
}
