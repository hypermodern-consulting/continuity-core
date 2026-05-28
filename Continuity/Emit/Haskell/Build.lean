import Continuity.Emit.Haskell.Ast
import Continuity.Emit.Haskell.Render

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // emit // haskell
                                                                     build.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Builder DSL — monadic helpers for ergonomic Haskell AST construction.

  Three builder monads:
    DoM   — accumulates do-notation statements
    DeclM — accumulates top-level declarations
    FieldM — accumulates record fields (data decl or record construction)

  Plus short aliases for the expression constructors you type a hundred
  times when writing codegen: var, con, app, apps, infix_, litInt, etc.
-/

namespace Continuity.Emit.Haskell


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // expression shortcuts
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! these save keystrokes in codegen call sites. every one is a trivial
    wrapper — the full constructors are always available if you prefer. -/

namespace E

def var (name : String) : HsExpr := HsExpr.var name
def con (name : String) : HsExpr := HsExpr.con name
def qual (m : String) (name : String) : HsExpr := HsExpr.qual m name
def litInt (n : Int) : HsExpr := HsExpr.litInt n
def litStr (s : String) : HsExpr := HsExpr.litStr s
def unit : HsExpr := HsExpr.unit

def app (fn : HsExpr) (arg : HsExpr) : HsExpr := HsExpr.app fn arg
def apps (fn : HsExpr) (args : List HsExpr) : HsExpr := HsExpr.apps fn args
def infix_ (op : String) (l : HsExpr) (r : HsExpr) : HsExpr := HsExpr.infix_ op l r
def parens (e : HsExpr) : HsExpr := HsExpr.parens e

def lam (params : List String) (body : HsExpr) : HsExpr :=
  HsExpr.lam (params.map HsPat.var) body

def ite (c : HsExpr) (t : HsExpr) (f : HsExpr) : HsExpr := HsExpr.ite c t f

def pure_ (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "pure") x
def return_ (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "return") x
def fromIntegral (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "fromIntegral") x

def typed (e : HsExpr) (ty : HsType) : HsExpr := HsExpr.typed e ty
def list (xs : List HsExpr) : HsExpr := HsExpr.list xs
def tuple (xs : List HsExpr) : HsExpr := HsExpr.tuple xs
def negate (e : HsExpr) : HsExpr := HsExpr.negate e

end E

-- ── pattern shortcuts ─────────────────────────────────────────────────────────

namespace P

def var (name : String) : HsPat := HsPat.var name
def wild : HsPat := HsPat.wild
def con (name : String) (args : List HsPat) : HsPat := HsPat.con name args
def tuple (ps : List HsPat) : HsPat := HsPat.tuple ps
def litInt (n : Int) : HsPat := HsPat.litInt n
def bang (p : HsPat) : HsPat := HsPat.bang p

end P

-- ── type shortcuts ────────────────────────────────────────────────────────────

namespace T

def con (name : String) : HsType := HsType.con name
def var (name : String) : HsType := HsType.var name
def app (f : HsType) (a : HsType) : HsType := HsType.app f a
def apps (f : HsType) (as : List HsType) : HsType := HsType.apps f as
def arrow (a : HsType) (b : HsType) : HsType := HsType.arrow a b
def list (a : HsType) : HsType := HsType.list a
def tuple (ts : List HsType) : HsType := HsType.tuple ts
def io (a : HsType) : HsType := HsType.io a
def maybe (a : HsType) : HsType := HsType.maybe a
def unit : HsType := HsType.unit
def promotedList (ts : List HsType) : HsType := HsType.promotedList ts

/-- `a -> b -> c` — chains of arrows -/
def arrows (ts : List HsType) : HsType :=
  match ts with
  | []          => HsType.unit
  | [single]    => single
  | first :: rest => HsType.arrow first (arrows rest)

end T


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // do-block builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates do-notation statements. Use with `buildDo do ...` -/
abbrev DoM := StateM (List DoStmt)

/-- `name <- expr` -/
def bind (name : String) (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.bind (HsPat.var name) expr]

/-- `pat <- expr` — bind with an arbitrary pattern -/
def bindPat (pat : HsPat) (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.bind pat expr]

/-- `_ <- expr` — bind and discard -/
def bind_ (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.bind HsPat.wild expr]

/-- `let name = expr` -/
def letBind (name : String) (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.letStmt (HsPat.var name) expr]

/-- `let pat = expr` — let with an arbitrary pattern -/
def letPat (pat : HsPat) (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.letStmt pat expr]

/-- bare expression (usually the last statement, or a void action) -/
def stmt (expr : HsExpr) : DoM Unit :=
  modify fun stmts => stmts ++ [DoStmt.expr expr]

/-- `pure expr` — idiomatic last statement -/
def ret (expr : HsExpr) : DoM Unit :=
  stmt (E.pure_ expr)

/-- Run a do-block builder, producing a do expression -/
def buildDo (m : DoM Unit) : HsExpr :=
  let (_, stmts) := m.run []
  HsExpr.do_ stmts


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // declaration builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates top-level declarations. Use with `buildDecls do ...` -/
abbrev DeclM := StateM (List HsDecl)

namespace DeclM

def pragma (kind : String) (value : String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.pragma kind value]

def import_ (moduleName : String) (names : List String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.importOnly moduleName names]

def importQ (moduleName : String) (alias : String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.importQualified moduleName alias]

def blank : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.blank]

def comment (text : String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.comment text]

def typeSig (name : String) (ty : HsType) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.typeSig name ty]

/-- simple function: one clause, no guards, no where -/
def fun_ (name : String) (pats : List HsPat) (body : HsExpr) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.simpleFun name pats body]

/-- type signature + function definition together -/
def sigFun (name : String) (ty : HsType) (pats : List HsPat) (body : HsExpr) : DeclM Unit :=
  modify fun ds => ds ++ [
    HsDecl.typeSig name ty,
    HsDecl.simpleFun name pats body
  ]

def data_ (name : String) (params : List String) (cons : List DataCon)
    (deriving_ : List String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.dataDef name params cons deriving_]

def newtype_ (name : String) (params : List String) (con : DataCon)
    (deriving_ : List String) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.newtypeDef name params con deriving_]

def typeAlias (name : String) (params : List String) (body : HsType) : DeclM Unit :=
  modify fun ds => ds ++ [HsDecl.typeAlias name params body]

end DeclM

/-- Run a declaration builder -/
def buildDecls (m : DeclM Unit) : List HsDecl :=
  let (_, ds) := m.run []
  ds


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // module builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Build a complete module from a declaration builder -/
def buildModule (name : String) (exports : Option (List String))
    (m : DeclM Unit) : HsModule :=
  { name := name
  , exports := exports
  , decls := buildDecls m }


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // record fields
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates record fields for data declarations or record expressions -/
abbrev FieldM := StateM (List (String × HsType))

/-- Add a field to a record type being built -/
def recordField (name : String) (ty : HsType) : FieldM Unit :=
  modify fun fs => fs ++ [(name, ty)]

/-- Run a field builder, producing a record data constructor -/
def buildRecordCon (name : String) (m : FieldM Unit) : DataCon :=
  let (_, fs) := m.run []
  DataCon.record name fs


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

-- ── do-block builder ──────────────────────────────────────────────────────────

#eval renderExpr (buildDo do
  bind "len"     <| E.var "getWord64le"
  bind "content" <| E.apps (E.var "getByteString") [E.fromIntegral (E.var "len")]
  letBind "padLen" <|
    E.infix_ "`mod`"
      (E.infix_ "-" (E.litInt 8)
        (E.infix_ "`mod`" (E.var "len") (E.litInt 8)))
      (E.litInt 8)
  bind_ <| E.apps (E.var "getByteString") [E.fromIntegral (E.var "padLen")]
  ret <| E.apps (E.con "NixString") [E.var "content"])

-- ── full module builder ───────────────────────────────────────────────────────

#eval renderModule (buildModule
  "Continuity.Codec.NixString"
  (Option.some ["NixString(..)", "parseNixString", "serializeNixString"])
  do
    DeclM.pragma "LANGUAGE" "StrictData"
    DeclM.blank
    DeclM.import_ "Data.ByteString" ["ByteString"]
    DeclM.importQ "Data.ByteString" "BS"
    DeclM.import_ "Data.Word" ["Word64"]
    DeclM.import_ "Data.Binary.Get" ["Get", "getWord64le", "getByteString"]
    DeclM.import_ "Data.Binary.Put" ["Put", "putWord64le", "putByteString"]
    DeclM.blank
    DeclM.data_ "NixString" []
      [buildRecordCon "NixString" do
        recordField "nixStringContent" (T.con "ByteString")]
      ["Show", "Eq"]
    DeclM.blank
    DeclM.sigFun "parseNixString"
      (T.app (T.con "Get") (T.con "NixString"))
      []
      (buildDo do
        bind "len" <| E.var "getWord64le"
        bind "content" <|
          E.apps (E.var "getByteString") [E.fromIntegral (E.var "len")]
        letBind "padLen" <|
          E.infix_ "`mod`"
            (E.infix_ "-" (E.litInt 8)
              (E.infix_ "`mod`" (E.var "len") (E.litInt 8)))
            (E.litInt 8)
        bind_ <|
          E.apps (E.var "getByteString") [E.fromIntegral (E.var "padLen")]
        ret <| E.apps (E.con "NixString") [E.var "content"]))


end Continuity.Emit.Haskell
