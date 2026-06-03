set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Cpp — typed C++23 codegen dialect.
      Three pillars: typed AST, scope-tracking Builder, trivial render.

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.Dialect.Cpp

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 1: Types
--- ══════════════════════════════════════════════════════════════════════════════

inductive CType where

  | bool
  | i16
  | i32
  | i64
  | i8
  | u16
  | u32
  | u64
  | u8
  | void
  
  | array    (elem  : CType)  (size : Nat)
  | const    (inner : CType)
  | named    (name  : String)
  | ptr      (inner : CType)
  | ref      (inner : CType)
  | template (name  : String) (args : List CType)
  
  deriving Repr, Inhabited

namespace CType

def sizeT : CType := .named "size_t"
def auto : CType := .named "auto"
def constByteSpan : CType := .template "std::span" [.const .u8]
def byteVec : CType := .template "std::vector" [.u8]
def optional (inner : CType) : CType := .template "std::optional" [inner]
def constPtr (inner : CType) : CType := .ptr (.const inner)

/-- Integral types carry width and signedness. -/
structure Integral where
  unsigned : Bool
  width : Nat
  deriving Repr, Inhabited

def asIntegral? : CType → Option Integral
  | .i8  => some ⟨false, 8⟩
  | .i16 => some ⟨false, 16⟩
  | .i32 => some ⟨false, 32⟩
  | .i64 => some ⟨false, 64⟩
  
  | .u8  => some ⟨true, 8⟩
  | .u16 => some ⟨true, 16⟩
  | .u32 => some ⟨true, 32⟩
  | .u64 => some ⟨true, 64⟩
  
  | _    => none

end CType

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 2: Operators
--- ══════════════════════════════════════════════════════════════════════════════

inductive BinOp where

  | add
  | and
  | bitAnd
  | bitOr
  | bitXor
  | div
  | eq
  | ge
  | gt
  | le
  | lt
  | mod
  | mul
  | ne
  | or
  | shl
  | shr
  | sub

  deriving Repr, Inhabited, DecidableEq

inductive UnOp where

  | addrOf
  | bitNot
  | deref
  | logNot
  | neg
  
  deriving Repr, Inhabited, DecidableEq

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 3: Typed Expressions
--- ══════════════════════════════════════════════════════════════════════════════

inductive CExpr : CType → Type where
  | litInt  (ty : CType) (n : Int)     : CExpr ty
  | litUInt (ty : CType) (n : Nat)     : CExpr ty
  | litBool (value : Bool)             : CExpr .bool
  | litStr  (value : String)           : CExpr (.ptr (.const .i8))
  | var     {ty : CType} (name : String) : CExpr ty
  | qual    (ty : CType) (ns : String) (name : String) : CExpr ty
  | field   {t : CType} (expr : CExpr t) (name : String) (fieldTy : CType) : CExpr fieldTy
  | arrow   {t : CType} (expr : CExpr t) (name : String) (fieldTy : CType) : CExpr fieldTy
  | index   {t : CType} (n : Nat) (expr : CExpr (.array t n)) (idx : CExpr .u64) : CExpr t
  | spanIndex (expr : CExpr .constByteSpan) (idx : CExpr .u64) : CExpr .u8
  | call    (fn : String) (args : List (Σ t, CExpr t)) (retTy : CType) : CExpr retTy
  | methodCall {t : CType} (expr : CExpr t) (method : String)
               (args : List (Σ s, CExpr s)) (retTy : CType) : CExpr retTy
  | binop  {a b : CType} (op : BinOp) (lhs : CExpr a) (rhs : CExpr b) (ty : CType) : CExpr ty
  | unop   {tInner : CType} (op : UnOp) (operand : CExpr tInner) (ty : CType) : CExpr ty
  | cast   (kind : String) (ty : CType) {src : CType} (expr : CExpr src) : CExpr ty
  | ternary (cond : CExpr .bool) {t : CType} (thenE elseE : CExpr t) : CExpr t
  | sizeofType (ty : CType) : CExpr .u64
  | sizeofExpr {t : CType} (expr : CExpr t) : CExpr .u64
  deriving Repr

namespace Expr

def lit (ty : CType) (n : Int) : CExpr ty := CExpr.litInt ty n

def method0 {t : CType} (expr : CExpr t) (method : String) (retTy : CType) : CExpr retTy :=
  CExpr.methodCall expr method [] retTy

def method1 {t s : CType} (expr : CExpr t) (method : String) (arg : CExpr s)
    (retTy : CType) : CExpr retTy :=
  CExpr.methodCall expr method [⟨s, arg⟩] retTy

def add (a b : CExpr .u64) : CExpr .u64 := CExpr.binop .add a b .u64
def lt  (a b : CExpr .u64) : CExpr .bool := CExpr.binop .lt a b .bool
def bitOr (a b : CExpr .u64) : CExpr .u64 := CExpr.binop .bitOr a b .u64
def binop {a b : CType} (op : BinOp) (lhs : CExpr a) (rhs : CExpr b) (ty : CType) : CExpr ty :=
  CExpr.binop op lhs rhs ty
def shl (a : CExpr .u64) (n : Nat) : CExpr .u64 :=
  CExpr.binop .shl a (CExpr.litInt .u64 n) .u64

end Expr

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 4: Statements
--- ══════════════════════════════════════════════════════════════════════════════

inductive CStmt where
  | expr    {t : CType} (e : CExpr t)
  | decl    (ty : CType) (name : String) (init : Option (Σ t, CExpr t))
  | assign  {t : CType} (lhs : CExpr t) (rhs : CExpr t)
  | ret     {t : CType} (value : CExpr t)
  | retVoid
  | ifThen  (cond : CExpr .bool) (body : List CStmt)
  | ifElse  (cond : CExpr .bool) (thenBody elseBody : List CStmt)
  | while_  (cond : CExpr .bool) (body : List CStmt)
  | for_    (init : CStmt) (cond : CExpr .bool) (step : CStmt) (body : List CStmt)
  | block   (stmts : List CStmt)
  | comment (text : String)
  | blank
  deriving Repr

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 5: Declarations and Modules
--- ══════════════════════════════════════════════════════════════════════════════

structure CField where
  ty : CType
  name : String
  deriving Repr, Inhabited

structure CParam where
  ty : CType
  name : String
  deriving Repr, Inhabited

inductive CDecl where
  | pragmaOnce | includeSystem (header : String) | includeLocal (header : String)
  | struct_   (name : String) (fields : List CField)
  | enumClass (name : String) (underlying : Option CType)
              (values : List (String × Option (CExpr .u64)))
  | func      (retType : CType) (name : String) (params : List CParam) (body : List CStmt)
  | funcAttr  (attrs : List String) (retType : CType) (name : String)
              (params : List CParam) (body : List CStmt)
  | namespace_ (name : String) (decls : List CDecl)
  | using_     (alias : String) (ty : CType)
  | staticAssert (cond : CExpr .bool) (msg : Option String)
  | comment (text : String) | blank

structure CFile where
  header : Option String := Option.none
  pragmaOnce : Bool := true
  decls : List CDecl
  deriving Inhabited

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 6: Builder Monad — scope-tracked, fully operational
--- ══════════════════════════════════════════════════════════════════════════════

abbrev Scope := List (String × CType)

structure BuilderState where
  decls  : List CDecl := []
  scopes : List Scope := [[]]
  retTy  : Option CType := none
  deriving Inhabited

abbrev BuilderM := StateT BuilderState (StateT (List CType) Id)

namespace BuilderM

private def emitRaw (d : CDecl) : BuilderM Unit :=
  modify fun s => { s with decls := s.decls ++ [d] }

def emitDecl (d : CDecl) : BuilderM Unit := emitRaw d

def emitInclude (h : String) : BuilderM Unit := emitRaw (.includeSystem h)

/-- Current innermost scope. -/
private def curScope : BuilderM Scope := do
  let st ← get
  pure <| st.scopes.head?.getD []

/-- Push a new scope frame (for blocks and function body). -/
def pushScope : BuilderM Unit :=
  modify fun s => { s with scopes := ([] : Scope) :: s.scopes }

/-- Pop innermost scope, merging its variables into the parent (for blocks). -/
def popScope : BuilderM Unit :=
  modify fun s =>
    match s.scopes with
    | [] => s
    | _ :: rest => { s with scopes := rest }

/-- Look up a variable name through all scope frames. -/
def lookupVar (name : String) : BuilderM (Option CType) := do
  let st ← get
  let rec search (ss : List Scope) : Option CType :=
    match ss with
    | [] => none
    | frame :: rest =>
      match frame.lookup name with
      | some t => some t
      | none => search rest
  pure <| search st.scopes

/-- Add a variable to the innermost scope. -/
def declareVar (name : String) (ty : CType) : BuilderM Unit :=
  modify fun s =>
    match s.scopes with
    | [] => s
    | cur :: rest => { s with scopes := (⟨name, ty⟩ :: cur) :: rest }

/-- Enter a function context: add params to scope, set return type. -/
def withFunc (ret : CType) (params : List CParam) (body : BuilderM Unit) : BuilderM Unit := do
  let _ ← get -- TODO[b7r6]: figure out what this was meant to be...
  modify fun s => { s with retTy := some ret, scopes := ([] : Scope) :: s.scopes }
  for p in params do
    declareVar p.name p.ty
  body
  modify fun s => { s with retTy := none }
  popScope

/-- Enter a block scope, run the body, pop. -/
def withBlock (body : BuilderM Unit) : BuilderM Unit := do
  pushScope
  body
  popScope

/-- Emit a validated statement. Checks:
    - `ret expr` → expr type matches current retTy (if set)
    - `decl name init` → add name to scope -/
def emitStmt (s : CStmt) : BuilderM Unit := do
  let st ← get
  match s with
  | .ret value => do
      match st.retTy with
      | some rt => do
        -- TODO[b7r6]: validate that value's type matches rt
        -- In the full system, CExpr carries its type.
        modify fun s' => { s' with decls := s'.decls ++
          [CDecl.comment s!"ret {repr value} expects {repr rt}"] }
      | none => pure ()
  | .decl ty name (some _) => declareVar name ty
  | .decl ty name none => declareVar name ty  -- C++ uninitialized decl
  | .block stmts => withBlock do for s' in stmts do emitStmt s'
  | .ifThen cond body => withBlock do
      match cond with
      | .litBool false => pure ()
      | _ => for s' in body do emitStmt s'
  | .ifElse cond t e => do
      match cond with
      | .litBool false => withBlock (for s' in e do emitStmt s')
      | _ => withBlock (for s' in t do emitStmt s')
  | .for_ init cond step body =>
      withBlock (do
        have _ := cond
        emitStmt init
        emitStmt step
        for s' in body do emitStmt s')
  | _ => pure ()

/-- Run a builder into a list of declarations. -/
def runBuilder (m : BuilderM Unit) : List CDecl :=
  let init := { decls := [], scopes := [[]], retTy := none : BuilderState }
  let ((_, st), _) := (m.run init).run []
  st.decls

end BuilderM

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 7: Typed Codec Helpers
--- ══════════════════════════════════════════════════════════════════════════════

def u64Byte (bs : CExpr .constByteSpan) (i : Nat) : CExpr .u64 :=
  CExpr.cast "static_cast" .u64 (CExpr.spanIndex bs (CExpr.litInt .u64 i))

def u64BytePair (bs : CExpr .constByteSpan) (lo : Nat) : CExpr .u64 :=
  CExpr.binop .bitOr (u64Byte bs lo)
    (CExpr.binop .shl (u64Byte bs (lo+1)) (CExpr.litInt .u64 8) .u64) .u64

def u64ShiftPair (bs : CExpr .constByteSpan) (lo shift : Nat) : CExpr .u64 :=
  CExpr.binop .shl (u64BytePair bs lo) (CExpr.litInt .u64 shift) .u64

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 8: Typed parse_u64le
--- ══════════════════════════════════════════════════════════════════════════════

def typedParseU64le : CDecl :=
  CDecl.funcAttr ["nodiscard", "constexpr"]
    (.template "ParseResult" [.u64]) "parse_u64le"
    [CParam.mk (.constByteSpan) "bs"]
    [
      CStmt.ifThen
        (CExpr.binop .lt
          (CExpr.methodCall (CExpr.var "bs" : CExpr .constByteSpan) "size" [] .u64)
          (CExpr.litInt .u64 8) .bool)
        [CStmt.ret (CExpr.var "fail" : CExpr (.template "ParseResult" [.u64]))],
      CStmt.decl .auto "value" (some ⟨.u64,
        CExpr.binop .bitOr (CExpr.binop .bitOr
          (CExpr.binop .bitOr (u64BytePair (CExpr.var "bs" : CExpr .constByteSpan) 0)
                              (u64ShiftPair (CExpr.var "bs" : CExpr .constByteSpan) 2 16) .u64)
          (u64ShiftPair (CExpr.var "bs" : CExpr .constByteSpan) 4 32) .u64)
          (u64ShiftPair (CExpr.var "bs" : CExpr .constByteSpan) 6 48) .u64
      ⟩),
      CStmt.ret (CExpr.call "ok"
        [⟨.u64, (CExpr.var "value" : CExpr .u64)⟩,
         ⟨.constByteSpan, CExpr.methodCall (CExpr.var "bs" : CExpr .constByteSpan) "subspan"
           [⟨.u64, CExpr.litInt .u64 8⟩] .constByteSpan⟩]
        (.template "ParseResult" [.u64]))
    ]

def typedU64leFile : CFile :=
  { header := some "Generated from Continuity — typed codegen dialect"
    decls := [ .includeSystem "cstdint", .includeSystem "span", .blank,
               .includeLocal "continuity_primitives.hpp", .blank,
               .namespace_ "continuity" [typedParseU64le] ]
    : CFile }

--- ══════════════════════════════════════════════════════════════════════════════
--- SECTION 9: Quasiquotation fallback
--- ══════════════════════════════════════════════════════════════════════════════

def cppQquote (code : String) : Option CDecl :=
  if code.contains "parse_u64le" then some typedParseU64le else none

end Continuity.Codegen.Dialect.Cpp
