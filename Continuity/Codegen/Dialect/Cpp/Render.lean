import Continuity.Codegen.Dialect.Cpp

set_option autoImplicit false


namespace Continuity.Codegen.Dialect.Cpp

/- 

  Render C++ typed AST → String. Zero bare delimiters or `++`.

  Architecture:
    - Delimiters  — parens, angled, braces, etc.
    - Combinators — indent, line, block, newlineSep
    - Syntax      — ifStmt, funcSig, struct_, etc.
    - Terms       — renderBinOp, renderIntegralType, etc.
    - Dispatch    — renderType, renderExpr, renderStmts, renderDecl,
 -/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // delimiters
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def angled     (s : String) : String := String.join ["<", s, ">"]
def braces     (s : String) : String := String.join ["{", s, "}"]
def brackets   (s : String) : String := String.join ["[", s, "]"]
def parens     (s : String) : String := String.join ["(", s, ")"]

def newline    (s : String) : String := String.join [s, "\n"]
def semicolon  (s : String) : String := String.join [s, ";"]

def quoteStr   (s : String) : String := String.join ["\"", s, "\""]

def commaSep   (xs : List String) : String := String.join (List.intersperse ", " xs)
def newlineSep (xs : List String) : String := String.join (List.intersperse "\n" xs)
def spaceSep   (xs : List String) : String := String.join (List.intersperse " "  xs)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def indentW (n : Nat) : String := String.join (List.replicate n "  ")

def line (i : Nat) (content : String) : String :=
  String.join [indentW i, content]

def semiline (i : Nat) (content : String) : String :=
  semicolon (line i content)

def block (i : Nat) (body : String) : String :=
  String.join [indentW i, braces (String.join ["\n", body, "\n"])]

def blankLine : String := "\n\n"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                    // syntax
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def includeSys  (h : String) : String := newline (String.join ["#include <", h, ">"])
def includeLoc  (h : String) : String := newline (String.join ["#include ", quoteStr h])

def pragmaOnce               : String := "#pragma once\n"
def comment     (t : String) : String := String.join ["// ", t]

def arrow          (e f : String)      : String := String.join [e, "->", f]
def dot            (e f : String)      : String := String.join [e, ".", f]
def qual           (ns n : String)     : String := String.join [ns, "::", n]

def callExpr       (fn args : String)  : String := String.join [fn, parens args]
def indexExpr      (e idx : String)    : String := String.join [e, brackets idx]
def methodCallExpr (e m args : String) : String := String.join [e, ".", m, parens args]

def castExpr    (k t e : String) : String := String.join [k, angled t, parens e]
def sizeofExpr  (s : String)     : String := String.join ["sizeof", parens s]

def ternaryExpr (c t f : String) : String :=
  String.join [parens c, " ? ", parens t, " : ", parens f]

def binopExpr (op a b : String) : String := parens (spaceSep [a, op, b])
def unopExpr  (op e : String)   : String := parens (String.join [op, e])

def declStruct (ty name : String) (init? : Option String) : String :=
  match init? with
  | some expr => spaceSep [ty, name, "=", expr]
  | none      => spaceSep [ty, name]

def returnStmt (e : String) : String := String.join ["return ", e]
def ifStmt     (c : String) : String := String.join ["if ", parens c]
def whileStmt  (c : String) : String := String.join ["while ", parens c]
def elseKw              : String := "else"

def forHeader (init cond step : String) : String :=
  parens (spaceSep [init, semicolon cond, step])

def structDecl (n : String) (body : String) : String :=
  String.join ["struct ", n, " ", braces (String.join ["\n", body, "\n"])]

def enumDecl (n : String) (underlying : Option String) (body : String) : String :=
  String.join ["enum class ", n,
    (match underlying with | some u => String.join [" : ", u] | none => ""),
    " ", braces (String.join ["\n", body, "\n"])]

def funcSig (ret name params : String) : String :=
  spaceSep [ret, String.join [name, parens params]]

def funcAttrSig (attrs : List String) (ret name params : String) : String :=
  String.join ["[[", commaSep attrs, "]] ", funcSig ret name params]

def namespaceDecl (n body : String) : String :=
  String.join ["namespace ", n, " ", braces (String.join ["\n", body, "\n"])]

def usingDecl (alias ty : String) : String :=
  semicolon (newline (spaceSep ["using", alias, "=", ty]))

def staticAssertDecl (expr : String) (msg? : Option String) : String :=
  let args := match msg? with
    | some m => commaSep [expr, quoteStr m]
    | none   => expr
  semicolon (newline (String.join ["static_assert", parens args]))

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // terms
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def renderIntegralType : Bool → Nat → String
  | false, 16 => "int16_t"
  | false, 32 => "int32_t"
  | false, 64 => "int64_t"
  | false, 8  => "int8_t"
  | true,  16 => "uint16_t"
  | true,  32 => "uint32_t"
  | true,  64 => "uint64_t"
  | true,  8  => "uint8_t"
  | u, w      => String.join [(if u then "uint" else "int"), toString w, "_t"]

def renderBinOp : BinOp → String
  | .add => "+"
  | .and => "&&"
  | .bitAnd => "&"
  | .bitOr => "|"
  | .bitXor => "^"
  | .div => "/"
  | .eq => "=="
  | .ge => ">="
  | .gt => ">"
  | .le => "<="
  | .lt => "<"
  | .mod => "%"
  | .mul => "*"
  | .ne => "!="
  | .or => "||"
  | .shl => "<<"
  | .shr => ">>"
  | .sub => "-"

def renderUnOp : UnOp → String
  | .addrOf => "&"
  | .bitNot => "~"
  | .deref => "*"
  | .logNot => "!"
  | .neg => "-"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // dipsatch
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

--- ═══ renderType arms ═══

mutual

def renderTypeArray (e : CType) (n : Nat) : String :=
  String.join ["std::array<", renderType e, ", ", toString n, ">"]

def renderTypeBool   : String := "bool"
def renderTypeVoid   : String := "void"

def renderTypeConst  (t : CType) : String := String.join ["const ", renderType t]
def renderTypeNamed  (n : String) : String := n

def renderTypePtr    (t : CType) : String := String.join [renderType t, "*"]
def renderTypeRef    (t : CType) : String := String.join [renderType t, "&"]

def renderTypeI8     : String := renderIntegralType false 8
def renderTypeI16    : String := renderIntegralType false 16
def renderTypeI32    : String := renderIntegralType false 32
def renderTypeI64    : String := renderIntegralType false 64

def renderTypeU8     : String := renderIntegralType true 8
def renderTypeU16    : String := renderIntegralType true 16
def renderTypeU32    : String := renderIntegralType true 32
def renderTypeU64    : String := renderIntegralType true 64

def renderTypeTemplate (n : String) (args : List CType) : String :=
  String.join [n, angled (commaSep (args.map renderType))]

def renderType : CType → String
  | .array e n     => renderTypeArray e n
  | .bool          => renderTypeBool
  | .const t       => renderTypeConst t
  | .i16           => renderTypeI16
  | .i32           => renderTypeI32
  | .i64           => renderTypeI64
  | .i8            => renderTypeI8
  | .named n       => renderTypeNamed n
  | .ptr t         => renderTypePtr t
  | .ref t         => renderTypeRef t
  | .u16           => renderTypeU16
  | .u32           => renderTypeU32
  | .u64           => renderTypeU64
  | .u8            => renderTypeU8
  | .void          => renderTypeVoid
  | .template n as => renderTypeTemplate n as

end

--- ═══ renderExpr arms ═══

partial def renderExpr (t : CType) (e : CExpr t) : String :=
  match e with
  | .litInt _ n              => renderLitInt t n
  | .litUInt _ n             => renderLitUInt t n
  | .litBool b               => renderLitBool b
  | .litStr s                => renderLitStr s
  | .var n                   => renderVar n
  | .qual _ ns n             => renderQual ns n
  | .field e n ft            => renderField e n ft
  | .arrow e n ft            => renderArrow e n ft
  | .index _ e idx           => renderIndex _ e idx
  | .spanIndex e idx         => renderSpanIndex e idx
  | .call fn args _          => renderCallExpr fn args t
  | .methodCall e m args _   => renderMethodCallExpr e m args t
  | .binop o a b _           => renderBinopExpr o a b t
  | .unop o e _              => renderUnopExpr o e t
  | .cast k ty e             => renderCastExpr k ty e
  | .ternary c th el         => renderTernaryExpr c th el
  | .sizeofType ty           => renderSizeofTypeExpr ty
  | .sizeofExpr e            => renderSizeofExprExpr e
where
  renderLitInt     (_ : CType) (n : Int)    : String := toString n
  renderLitUInt    (_ : CType) (n : Nat)    : String := String.join [toString n, "ULL"]
  renderLitBool    (b : Bool)               : String := if b then "true" else "false"
  renderLitStr     (s : String)             : String := quoteStr s
  renderVar        (name : String)          : String := name
  renderQual       (ns n : String)          : String := qual ns n

  renderField      {t : CType} (e : CExpr t) (name : String) (_ : CType) : String :=
    dot (renderExpr _ e) name

  renderArrow      {t : CType} (e : CExpr t) (name : String) (_ : CType) : String :=
    arrow (renderExpr _ e) name

  renderIndex      {t : CType} (n : Nat) (e : CExpr (.array t n)) (idx : CExpr .u64) : String :=
    indexExpr (renderExpr _ e) (renderExpr _ idx)

  renderSpanIndex  (e : CExpr .constByteSpan) (idx : CExpr .u64) : String :=
    indexExpr (renderExpr _ e) (renderExpr _ idx)

  renderCallExpr   (fn : String) (args : List (Σ s, CExpr s)) (_ : CType) : String :=
    callExpr fn (commaSep (args.map fun ⟨_, a⟩ => renderExpr _ a))

  renderMethodCallExpr {t : CType} (e : CExpr t) (method : String)
      (args : List (Σ s, CExpr s)) (_ : CType) : String :=
    methodCallExpr (renderExpr _ e) method (commaSep (args.map fun ⟨_, a⟩ => renderExpr _ a))

  renderBinopExpr  {a b : CType} (op : BinOp) (lhs : CExpr a) (rhs : CExpr b) (_ : CType) : String :=
    binopExpr (renderBinOp op) (renderExpr _ lhs) (renderExpr _ rhs)

  renderUnopExpr   {tInner : CType} (op : UnOp) (e : CExpr tInner) (_ : CType) : String :=
    unopExpr (renderUnOp op) (renderExpr _ e)

  renderCastExpr   (kind : String) (ty : CType) {src : CType} (e : CExpr src) : String :=
    castExpr kind (renderType ty) (renderExpr _ e)

  renderTernaryExpr (cond : CExpr .bool) {t : CType} (thenE elseE : CExpr t) : String :=
    ternaryExpr (renderExpr _ cond) (renderExpr _ thenE) (renderExpr _ elseE)

  renderSizeofTypeExpr (ty : CType) : String :=
    sizeofExpr (renderType ty)

  renderSizeofExprExpr {t : CType} (e : CExpr t) : String :=
    sizeofExpr (renderExpr _ e)

--- ═══ renderParams ═══

def renderParams (ps : List CParam) : String :=
  commaSep (ps.map fun p => spaceSep [renderType p.ty, p.name])

--- ═══ renderStmts + renderStmt arms ═══

def renderIfThenStmt (renderBody : List CStmt → Nat → String) (depth : Nat)
    (c : CExpr .bool) (b : List CStmt) : String :=
  line depth (spaceSep [ifStmt (renderExpr _ c), renderBody b depth])

def renderIfElseStmt (renderBody : List CStmt → Nat → String) (depth : Nat)
    (c : CExpr .bool) (t e : List CStmt) : String :=
  line depth (spaceSep [ifStmt (renderExpr _ c), renderBody t depth, elseKw, renderBody e depth])

def renderWhileStmt (renderBody : List CStmt → Nat → String) (depth : Nat)
    (c : CExpr .bool) (b : List CStmt) : String :=
  line depth (spaceSep [whileStmt (renderExpr _ c), renderBody b depth])

def renderForStmt (renderStmtFn : Nat → CStmt → String)
    (renderBody : List CStmt → Nat → String) (depth : Nat)
    (init : CStmt) (cond : CExpr .bool) (step : CStmt) (body : List CStmt) : String :=
  line depth (spaceSep
    [String.join ["for ", forHeader (renderStmtFn 0 init) (renderExpr _ cond) (renderStmtFn 0 step)],
     renderBody body depth])

def renderBlockStmt (renderBody : List CStmt → Nat → String) (depth : Nat) (ss : List CStmt) : String :=
  renderBody ss depth

partial def renderStmts (stmts : List CStmt) (ind : Nat) : String :=
  newlineSep (stmts.map (renderStmt ind))
where
  renderBody (body : List CStmt) (depth : Nat) : String :=
    block depth (renderStmts body (depth+1))

  renderExprStmt (depth : Nat) {t : CType} (e : CExpr t) : String :=
    semiline depth (renderExpr _ e)

  renderDeclStmtInit (depth : Nat) (ty : CType) (name : String) {t : CType} (init : CExpr t) : String :=
    semiline depth (declStruct (renderType ty) name (some (renderExpr _ init)))

  renderDeclStmt (depth : Nat) (ty : CType) (name : String) : String :=
    semiline depth (spaceSep [renderType ty, name])

  renderAssignStmt (depth : Nat) {t : CType} (lhs rhs : CExpr t) : String :=
    semiline depth (spaceSep [renderExpr _ lhs, "=", renderExpr _ rhs])

  renderRetStmt (depth : Nat) {t : CType} (e : CExpr t) : String :=
    semiline depth (returnStmt (renderExpr _ e))

  renderRetVoidStmt (depth : Nat) : String :=
    line depth "return;"

  renderCommentStmt (depth : Nat) (t : String) : String :=
    line depth (comment t)

  renderBlankStmt : String := ""

  renderStmt (depth : Nat) (s : CStmt) : String :=
    match s with
    | .expr e                        => renderExprStmt depth e
    | .decl ty name (some ⟨_, init⟩) => renderDeclStmtInit depth ty name init
    | .decl ty name none             => renderDeclStmt depth ty name
    | .assign lhs rhs                => renderAssignStmt depth lhs rhs
    | .ret e                         => renderRetStmt depth e
    | .retVoid                       => renderRetVoidStmt depth
    | .ifThen c b                    => renderIfThenStmt renderBody depth c b
    | .ifElse c t e                  => renderIfElseStmt renderBody depth c t e
    | .while_ c b                    => renderWhileStmt renderBody depth c b
    | .for_ init cond step body      => renderForStmt renderStmt renderBody depth init cond step body
    | .block ss                      => renderBlockStmt renderBody depth ss
    | .comment t                     => renderCommentStmt depth t
    | .blank                         => renderBlankStmt

--- ═══ renderDecl arms ═══

def renderStructFields (fs : List CField) : String :=
  newlineSep (fs.map fun f => semiline 1 (spaceSep [renderType f.ty, f.name]))

def renderEnumValues (vs : List (String × Option (CExpr .u64))) : String :=
  newlineSep (vs.map fun (v, val) =>
    match val with
    | some e => line 1 (String.join [v, " = ", renderExpr _ e, ","])
    | none   => line 1 (String.join [v, ","]))

def renderDeclPragmaOnce : String := pragmaOnce
def renderDeclBlank : String := "\n"

def renderDeclIncludeSystem (h : String) : String := includeSys h
def renderDeclIncludeLocal (h : String) : String := includeLoc h
def renderDeclComment (t : String) : String := newline (comment t)

def renderDeclStruct (n : String) (fs : List CField) : String :=
  newline (structDecl n (renderStructFields fs))

def renderDeclEnumClass (n : String) (u : Option CType)
    (vs : List (String × Option (CExpr .u64))) : String :=
  newline (enumDecl n (u.map renderType) (renderEnumValues vs))

def renderDeclUsing (a : String) (t : CType) : String :=
  usingDecl a (renderType t)

def renderDeclFunc (r : CType) (n : String) (ps : List CParam) (b : List CStmt) : String :=
  String.join [funcSig (renderType r) n (renderParams ps), " {\n", renderStmts b 1, "}\n"]

def renderDeclFuncAttr (as : List String) (r : CType) (n : String)
    (ps : List CParam) (b : List CStmt) : String :=
  String.join [funcAttrSig as (renderType r) n (renderParams ps), " {\n", renderStmts b 1, "}\n"]

def renderDeclStaticAssert (c : CExpr .bool) (msg : Option String) : String :=
  staticAssertDecl (renderExpr _ c) msg

mutual
  def renderDecl (d : CDecl) : String :=
    match d with
    | .blank                => renderDeclBlank
    | .comment t            => renderDeclComment t
    | .enumClass n u vs     => renderDeclEnumClass n u vs
    | .func r n ps b        => renderDeclFunc r n ps b
    | .funcAttr as r n ps b => renderDeclFuncAttr as r n ps b
    | .includeLocal h       => renderDeclIncludeLocal h
    | .includeSystem h      => renderDeclIncludeSystem h
    | .namespace_ n ds      => renderDeclNamespace n ds
    | .pragmaOnce           => renderDeclPragmaOnce
    | .staticAssert c m     => renderDeclStaticAssert c m
    | .struct_ n fs         => renderDeclStruct n fs
    | .using_ a t           => renderDeclUsing a t

  def renderDeclNamespace (n : String) (ds : List CDecl) : String :=
    newline (namespaceDecl n (String.join (ds.map renderDecl)))
end

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // file
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def renderFile (f : CFile) : String :=
  String.join [
    (match f.header with | some s => newline (newline (String.join ["// ", s])) | none => ""),
    (if f.pragmaOnce then newline pragmaOnce else ""),
    String.join (f.decls.map renderDecl)
  ]

end Continuity.Codegen.Dialect.Cpp
