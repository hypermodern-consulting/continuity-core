import Continuity.Codegen.Codec.Spec
import Continuity.Codegen.AST.Haskell.Ast
import Continuity.Codegen.AST.Haskell.Render

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "You can go home now, Turner. We're done with you. You're good as
      new." He'd been rebuilt from the ground up, the Hosaka surgeons
      replacing what the Russians had taken, his nervous system spliced
      and re-spliced until the output matched the blueprint. He felt the
      new circuits settling into place, a kind of low-level hum that told
      him the work was sound — that the translation from pattern to flesh
      had succeeded, every instruction rendered faithfully in the target.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Codec

/-
  Codec-to-`Haskell` translation.
  Maps wire-type specifications from `Codec/Spec.lean` into
  `Haskell` modules using binary `Get`/`Put` combinators.
  Output: a set of `codec/<Module>.hs` files suitable for
  `cabal` or `stack` builds.
-/

open Continuity.Codegen.AST.Haskell

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                              // wire // type // mapping
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def wireTypeToHsType : WireType → HsType
  | .u8 => HsType.con "Word8"
  | .u16le | .u16be => HsType.con "Word16"
  | .u32le | .u32be => HsType.con "Word32"
  | .u64le | .u64be => HsType.con "Word64"
  | .bool64 => HsType.con "Bool"
  | .varint => HsType.con "Word64"
  | .bytes _ => HsType.qual "BS" "ByteString"
  | .lenPrefixed => HsType.qual "BS" "ByteString"
  | .padded _ => HsType.qual "BS" "ByteString"

private def wireTypeGetter : WireType → String
  | .u8 => "getWord8" | .u16le => "getWord16le" | .u32le => "getWord32le"
  | .u64le => "getWord64le" | .u16be => "getWord16be" | .u32be => "getWord32be"
  | .u64be => "getWord64be" | .bool64 => "getBool64" | .varint => "getVarint"
  | .bytes n => s!"getByteString {n}" | .lenPrefixed => "getLenPrefixed"
  | .padded n => s!"getPaddedBytes {n}"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                              // helper // constructors
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def mkClause (pats : List HsPat) (body : HsExpr) : FunClause :=
  ⟨pats, RHS.simple body, []⟩

private def lcFirst (s : String) : String :=
  match s.toList with
  | c :: rest => String.ofList (c.toLower :: rest)
  | [] => s

private def ucFirst (s : String) : String :=
  match s.toList with
  | c :: rest => String.ofList (c.toUpper :: rest)
  | [] => s

private def escapeHsKeyword (s : String) : String :=
  if s ∈ ["data", "type", "class", "instance", "module", "import", "where",
          "let", "in", "do", "if", "then", "else", "case", "of", "default"] then
    s ++ "_"
  else s

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                            // codec // enumerations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def enumDataDecl (e : EnumSpec) : HsDecl :=
  HsDecl.dataDef e.name []
    (e.variants.map fun v => DataCon.positional v.name [])
    ["Show", "Eq", "Ord", "Bounded"]

private def enumToCodeFn (e : EnumSpec) : HsDecl :=
  HsDecl.funDef (e.name.toLower ++ "ToCode")
    (e.variants.map fun v => mkClause [HsPat.con v.name []] (HsExpr.litInt v.code))

private def enumFromCodeFn (e : EnumSpec) : HsDecl :=
  let clauses := e.variants.map fun v =>
    mkClause [HsPat.litInt v.code] (HsExpr.app (HsExpr.con "Just") (HsExpr.con v.name))
  let fallback := mkClause [HsPat.wild] (HsExpr.con "Nothing")
  HsDecl.funDef (e.name.toLower ++ "FromCode") (clauses ++ [fallback])

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                               // codec // structures
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def structDataDecl (s : StructSpec) : HsDecl :=
  HsDecl.dataDef s.name []
    [DataCon.record s.name (s.fields.map fun f =>
      (lcFirst s.name ++ ucFirst (escapeHsKeyword f.name), wireTypeToHsType f.wireType))]
    ["Show", "Eq"]

private def structParseFn (s : StructSpec) : HsDecl :=
  let binds := s.fields.map fun f =>
    DoStmt.bind (HsPat.var (lcFirst s.name ++ ucFirst (escapeHsKeyword f.name)))
      (HsExpr.var (wireTypeGetter f.wireType))
  let ret := DoStmt.expr (HsExpr.app (HsExpr.var "pure")
    (HsExpr.apps (HsExpr.con s.name) (s.fields.map fun f =>
      HsExpr.var (lcFirst s.name ++ ucFirst (escapeHsKeyword f.name)))))
  HsDecl.funDef (s!"parse{s.name}") [mkClause [] (HsExpr.do_ (binds ++ [ret]))]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                // codec // constants
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def constDecl (c : ConstSpec) : HsDecl :=
  HsDecl.funDef (lcFirst c.name) [mkClause [] (HsExpr.litInt c.value)]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // codec // module
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def moduleToHsModule (m : CodecModule) : HsModule :=
  let imports : List HsDecl := [
    HsDecl.import_ "Data.Word" false none ImportSpec.all,
    HsDecl.import_ "Data.ByteString" true (some "BS") (ImportSpec.only ["ByteString"]),
    HsDecl.import_ "Data.Binary.Get" false none (ImportSpec.only ["Get", "getWord8",
      "getWord16le", "getWord32le", "getWord64le", "getWord16be", "getWord32be", "getWord64be",
      "getByteString", "getRemainingLazyByteString"]),
    HsDecl.import_ "Data.Binary.Put" false none (ImportSpec.only ["Put", "putWord8",
      "putWord64le", "putByteString"]),
    HsDecl.import_ "Data.Bits" false none (ImportSpec.only ["(.&.)", "(.|.)", "shiftL", "shiftR",
      "testBit"])
  ]
  let helpers : List HsDecl := [
    HsDecl.blank,
    HsDecl.comment "Wire format helpers",
    HsDecl.funDef "getVarint" [mkClause []
      (HsExpr.var "getWord64le")],
    HsDecl.funDef "getLenPrefixed" [mkClause []
      (HsExpr.do_ [
        DoStmt.bind (HsPat.var "len") (HsExpr.var "getWord64le"),
        DoStmt.expr (HsExpr.apps (HsExpr.var "getByteString") [
          HsExpr.app (HsExpr.var "fromIntegral") (HsExpr.var "len")])])],
    HsDecl.funDef "getBool64" [mkClause []
      (HsExpr.do_ [
        DoStmt.bind (HsPat.var "v") (HsExpr.var "getWord64le"),
        DoStmt.expr (HsExpr.apps (HsExpr.var "pure") [
          HsExpr.parens (HsExpr.infix_ "/=" (HsExpr.var "v") (HsExpr.litInt 0))])])],
    HsDecl.blank
  ]
  let decls : List HsDecl :=
    helpers ++
    (m.constants.map constDecl) ++
    (if m.constants.isEmpty then [] else [HsDecl.blank]) ++
    (m.enums.flatMap fun e => [enumDataDecl e, HsDecl.blank, enumToCodeFn e, enumFromCodeFn e]) ++
    (if m.enums.isEmpty then [] else [HsDecl.blank]) ++
    (m.structs.flatMap fun s => [structDataDecl s, HsDecl.blank, structParseFn s])
  { name := s!"Continuity.Codec.{m.name}"
    exports := none
    decls := imports ++ [HsDecl.blank] ++ decls }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // output // files
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def hsCodecFiles : List (String × String) :=
  allModules.map fun m =>
    let mod := moduleToHsModule m
    (s!"codec/{m.name}.hs", renderModule mod)

end Continuity.Codegen.Codec
