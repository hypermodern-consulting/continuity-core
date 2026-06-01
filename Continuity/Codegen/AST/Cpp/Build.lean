import Continuity.Codegen.AST.Cpp.Ast
import Continuity.Codegen.AST.Cpp.Render

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  // continuity // build // cpp
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Builder DSL — monadic helpers for ergonomic C++ AST construction.

  Two builder monads:
    StmtM — accumulates statements (function bodies, if-blocks, loops)
    FileM — accumulates top-level declarations (includes, structs, functions)

  Plus short aliases in the `C` namespace for expression building
  and `Ty` for type building. Same idea as Haskell's `E`/`T`/`P`.

  The key ergonomic win: statement builders. A pack function goes from

    [CStmt.expr (CExpr.call "memcpy" [CExpr.addOffset "buf" 0,
      CExpr.unop UnOp.addrOf (CExpr.field (CExpr.var "s") "magic"),
      CExpr.litInt 8])]

  to

    buildStmts do
      memcpy (C.addOffset "buf" 0) (C.addrOfField "s" "magic") 8
      memcpy (C.addOffset "buf" 8) (C.addrOfField "s" "tag_len") 8
-/

namespace Continuity.Codegen.AST.Cpp

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                     // expression // shortcuts
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-! the `C` namespace holds one-liner expression builders. short and
    unambiguous — `C.var`, `C.call`, `C.field`. same role as `E` in
    the Haskell builder. -/

namespace C

def var (name : String) : CExpr := CExpr.var name
def litInt (n : Int) : CExpr := CExpr.litInt n
def litUInt (n : Nat) (suffix : String := "") : CExpr := CExpr.litUInt n suffix
def litStr (s : String) : CExpr := CExpr.litStr s
def litBool (b : Bool) : CExpr := CExpr.litBool b
def true_ : CExpr := CExpr.litBool true
def false_ : CExpr := CExpr.litBool false

def field (e : CExpr) (name : String) : CExpr := CExpr.field e name
def arrow (e : CExpr) (name : String) : CExpr := CExpr.arrow e name
def index (e : CExpr) (i : CExpr) : CExpr := CExpr.index e i
def indexN (e : CExpr) (i : Nat) : CExpr := CExpr.index e (CExpr.litInt i)

def call (fn : String) (args : List CExpr) : CExpr := CExpr.call fn args

def methodCall (e : CExpr) (m : String) (args : List CExpr) : CExpr :=
  CExpr.methodCall e m args
  
def method0 (e : CExpr) (m : String) : CExpr := CExpr.methodCall e m []

-- ── arithmetic ────────────────────────────────────────────────────────────────

def add (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.add a b
def sub (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.sub a b
def mul (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.mul a b
def mod (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.mod a b

-- ── comparison ────────────────────────────────────────────────────────────────

def eq (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.eq a b
def ne (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.ne a b
def lt (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.lt a b
def le (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.le a b
def gt (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.gt a b
def ge (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.ge a b

-- ── bitwise ───────────────────────────────────────────────────────────────────

def bitAnd (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.bitAnd a b
def bitOr (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.bitOr a b
def shl (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.shl a b
def shr (a : CExpr) (b : CExpr) : CExpr := CExpr.binop BinOp.shr a b

-- ── unary ─────────────────────────────────────────────────────────────────────

def addrOf (e : CExpr) : CExpr := CExpr.unop UnOp.addrOf e
def deref (e : CExpr) : CExpr := CExpr.unop UnOp.deref e
def logNot (e : CExpr) : CExpr := CExpr.unop UnOp.logNot e
def bitNot (e : CExpr) : CExpr := CExpr.unop UnOp.bitNot e
def neg (e : CExpr) : CExpr := CExpr.unop UnOp.neg e

-- ── compound ──────────────────────────────────────────────────────────────────

def addrOfField (structVar : String) (fieldName : String) : CExpr :=
  CExpr.addrOfField structVar fieldName

def addOffset (buf : String) (offset : Nat) : CExpr :=
  CExpr.addOffset buf offset

def staticCast (ty : CType) (e : CExpr) : CExpr :=
  CExpr.cast "static_cast" ty e

def reinterpretCast (ty : CType) (e : CExpr) : CExpr :=
  CExpr.cast "reinterpret_cast" ty e

def ternary (c : CExpr) (t : CExpr) (f : CExpr) : CExpr :=
  CExpr.ternary c t f

def parens (e : CExpr) : CExpr := CExpr.parens e
def sizeofTy (ty : CType) : CExpr := CExpr.sizeofType ty

def nullopt : CExpr := CExpr.qual "std" "nullopt"

end C

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                           // type // shortcuts
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-! `Ty` namespace for type construction. CType already has u8/u64/etc.
    as namespace members, so `Ty` just re-exports and adds convenience. -/

namespace Ty

def void      : CType := CType.void
def bool      : CType := CType.bool
def u8        : CType := CType.u8
def u16       : CType := CType.u16
def u32       : CType := CType.u32
def u64       : CType := CType.u64
def i8        : CType := CType.i8
def i16       : CType := CType.i16
def i32       : CType := CType.i32
def i64       : CType := CType.i64
def sizeT     : CType := CType.sizeT
def auto      : CType := CType.auto
def named (n : String) : CType := CType.named n

def ptr (t : CType) : CType := CType.ptr t
def ref (t : CType) : CType := CType.ref t
def const_ (t : CType) : CType := CType.const t
def constPtr (t : CType) : CType := CType.constPtr t
def constRef (t : CType) : CType := CType.constRef t

def constByteSpan : CType := CType.constByteSpan
def byteVec       : CType := CType.byteVec
def optional (t : CType) : CType := CType.optional t
def array (t : CType) (n : Nat) : CType := CType.array t n

end Ty

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                        // statement // builder
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-- Accumulates C++ statements. Use with `buildStmts do ...` -/
abbrev StmtM := StateM (List CStmt)

-- ── core statement emitters ───────────────────────────────────────────────────

/-- emit a raw statement -/
def emit (s : CStmt) : StmtM Unit :=
  modify fun ss => ss ++ [s]

/-- emit an expression as a statement: `expr;` -/
def exprStmt (e : CExpr) : StmtM Unit := emit (CStmt.expr e)

/-- `type name = init;` or `type name;` -/
def decl (ty : CType) (name : String) (init : Option CExpr := Option.none) : StmtM Unit :=
  emit (CStmt.decl ty name init)

/-- `lhs = rhs;` -/
def assign (lhs : CExpr) (rhs : CExpr) : StmtM Unit :=
  emit (CStmt.assign lhs rhs)

/-- `lhs op= rhs;` -/
def assignOp (op : BinOp) (lhs : CExpr) (rhs : CExpr) : StmtM Unit :=
  emit (CStmt.assignOp op lhs rhs)

/-- `return expr;` -/
def ret (e : CExpr) : StmtM Unit := emit (CStmt.ret e)

/-- `return;` -/
def retVoid : StmtM Unit := emit CStmt.retVoid

/-- `// comment` -/
def comment (text : String) : StmtM Unit := emit (CStmt.comment text)

/-- blank line -/
def blank : StmtM Unit := emit CStmt.blank

-- ── compound statements ──────────────────────────────────────────────────────

/-- `if (cond) { body }` -/
def ifThen (cond : CExpr) (body : StmtM Unit) : StmtM Unit :=
  let (_, stmts) := body.run []
  emit (CStmt.ifElse cond stmts Option.none)

/-- `if (cond) { thenBody } else { elseBody }` -/
def ifElse (cond : CExpr) (thenBody : StmtM Unit) (elseBody : StmtM Unit) : StmtM Unit :=
  let (_, thenStmts) := thenBody.run []
  let (_, elseStmts) := elseBody.run []
  emit (CStmt.ifElse cond thenStmts (Option.some elseStmts))

/-- `for (type i = init; cond; step) { body }` -/
def forLoop (ty : CType) (name : String) (init : CExpr) (cond : CExpr) (step : CExpr)
    (body : StmtM Unit) : StmtM Unit :=
  let (_, stmts) := body.run []
  emit (CStmt.for_ (CStmt.decl ty name (Option.some init)) cond step stmts)

/-- `for (auto& name : range) { body }` -/
def rangeFor (name : String) (range : CExpr) (body : StmtM Unit) : StmtM Unit :=
  let (_, stmts) := body.run []
  emit (CStmt.rangeFor (CType.ref CType.auto) name range stmts)

-- ── codec-specific helpers ────────────────────────────────────────────────────

/-- `memcpy(dst, src, n);` -/
def memcpy (dst : CExpr) (src : CExpr) (n : Nat) : StmtM Unit :=
  exprStmt (CExpr.memcpy dst src n)

/-- `if (lenExpr < minSize) return std::nullopt;` -/
def sizeCheck (lenExpr : CExpr) (minSize : Nat) : StmtM Unit :=
  emit (CStmt.sizeCheck lenExpr minSize)

/-- `out.push_back(expr);` -/
def pushBack (vec : String) (value : CExpr) : StmtM Unit :=
  exprStmt (CExpr.methodCall (CExpr.var vec) "push_back" [value])

/-- Run a statement builder, producing a statement list -/
def buildStmts (m : StmtM Unit) : List CStmt :=
  let (_, stmts) := m.run []
  stmts


/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                      // declaration // builder
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-- accumulates C++ top-level declarations. Use with `buildFile do ...` -/
abbrev FileM := StateM (List CDecl)

namespace FileM

def includeSystem (header : String) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.includeSystem header]

def includeLocal (header : String) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.includeLocal header]

def blank : FileM Unit :=
  modify fun ds => ds ++ [CDecl.blank]

def comment (text : String) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.comment text]

/-- struct from a list of (type, name) pairs -/
def struct_ (name : String) (fields : List (CType × String)) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.struct_ name (fields.map fun (t, n) => ⟨t, n⟩)]

/-- function with body built from a StmtM -/
def func (retTy : CType) (name : String) (params : List (CType × String))
    (body : StmtM Unit) : FileM Unit :=
  let ps : List CParam := params.map fun (t, n) => ⟨t, n⟩
  modify fun ds => ds ++ [CDecl.func retTy name ps (buildStmts body)]

/-- namespace wrapping a nested FileM -/
def namespace_ (name : String) (inner : FileM Unit) : FileM Unit :=
  let (_, decls) := inner.run []
  modify fun ds => ds ++ [CDecl.namespace_ name decls]

def using_ (alias : String) (ty : CType) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.using_ alias ty]

def staticAssert (cond : CExpr) (msg : Option String := Option.none) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.staticAssert cond msg]

def enumClass (name : String) (underlying : Option CType)
    (values : List String) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.enumClass name underlying
    (values.map fun v => (v, Option.none))]

def raw (text : String) : FileM Unit :=
  modify fun ds => ds ++ [CDecl.raw text]

end FileM

/-- run a declaration builder, producing a CFile -/
def buildFile (header : Option String := Option.none) (m : FileM Unit) : CFile :=
  let (_, decls) := m.run []
  { header := header, decls := decls }


/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                                       // tests
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

-- TODO[b7r6]: !! write real tests !!

-- ── statement builder ─────────────────────────────────────────────────────────

-- #eval renderFile (buildFile (Option.some "Generated by Continuity — do not edit") do
--   FileM.includeSystem "cstdint"
--   FileM.includeSystem "cstring"
--   FileM.includeSystem "span"
--   FileM.includeSystem "optional"
--   FileM.blank
--   FileM.namespace_ "continuity" do
--     FileM.struct_ "NarHeader" [
--       (Ty.u64, "magic"),
--       (Ty.u64, "tag_len")
--     ]
--     FileM.blank
--     FileM.staticAssert
--       (C.eq (C.sizeofTy (Ty.named "NarHeader")) (C.litInt 16))
--       (Option.some "NarHeader must be 16 bytes")
--     FileM.blank
--     FileM.func Ty.void "pack_NarHeader"
--       [(Ty.constRef (Ty.named "NarHeader"), "s"),
--        (Ty.ptr Ty.u8, "buf")]
--       do
--         memcpy (C.addOffset "buf" 0) (C.addrOfField "s" "magic") 8
--         memcpy (C.addOffset "buf" 8) (C.addrOfField "s" "tag_len") 8
--     FileM.blank
--     FileM.func (Ty.optional (Ty.named "NarHeader")) "parse_NarHeader"
--       [(Ty.constByteSpan, "buf")]
--       do
--         sizeCheck (C.method0 (C.var "buf") "size") 16
--         decl (Ty.named "NarHeader") "out"
--         memcpy (C.addrOfField "out" "magic") (C.method0 (C.var "buf") "data") 8
--         memcpy (C.addrOfField "out" "tag_len")
--           (C.add (C.method0 (C.var "buf") "data") (C.litInt 8)) 8
--         ret (C.var "out"))


end Continuity.Codegen.AST.Cpp
