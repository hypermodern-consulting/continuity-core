import Continuity.Emit.Cpp.Ast

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  // continuity // emit // cpp
                                                                   render.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  C++ renderer — the ONLY place C++ text is assembled.

  Four render functions:
    renderType — types (no trailing space; caller adds where needed)
    renderExpr — expressions (no semicolons; statements add them)
    renderStmt — statements (semicolons, braces, indentation)
    renderDecl — top-level declarations

  renderFile assembles a complete .hpp with pragma-once and header comment.
-/

namespace Continuity.Emit.Cpp

private def pad (n : Nat) : String := "".pushn ' ' n

private def escapeStr (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '"'  => acc ++ "\\\""
    | '\n' => acc ++ "\\n"
    | '\t' => acc ++ "\\t"
    | '\x00' => acc ++ "\\0"
    | c    => acc.push c
  ) ""


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // render type
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderType (ty : CType) : String :=
  match ty with
  | CType.void   => "void"
  | CType.bool   => "bool"
  | CType.sizeT  => "size_t"
  | CType.auto   => "auto"

  | CType.intType unsigned bits =>
    let pfx := if unsigned then "uint" else "int"
    s!"{pfx}{bits}_t"

  | CType.floatType 32 => "float"
  | CType.floatType 64 => "double"
  | CType.floatType n  => s!"float{n}_t"

  | CType.named name     => name
  | CType.qualified ns n => s!"{ns}::{n}"

  | CType.ptr inner   => s!"{renderType inner}*"
  | CType.ref inner   => s!"{renderType inner}&"
  | CType.const inner => s!"const {renderType inner}"

  | CType.array elem size =>
    s!"std::array<{renderType elem}, {size}>"

  | CType.template name args =>
    let argStr := ", ".intercalate (args.map renderType)
    s!"{name}<{argStr}>"


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // operators
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderBinOp : BinOp → String
  | BinOp.add    => "+"  | BinOp.sub    => "-"
  | BinOp.mul    => "*"  | BinOp.div    => "/"
  | BinOp.mod    => "%"
  | BinOp.eq     => "==" | BinOp.ne     => "!="
  | BinOp.lt     => "<"  | BinOp.le     => "<="
  | BinOp.gt     => ">"  | BinOp.ge     => ">="
  | BinOp.bitAnd => "&"  | BinOp.bitOr  => "|"
  | BinOp.bitXor => "^"
  | BinOp.shl    => "<<" | BinOp.shr    => ">>"
  | BinOp.and    => "&&" | BinOp.or     => "||"

private def renderUnOp : UnOp → String
  | UnOp.neg    => "-"  | UnOp.logNot => "!"
  | UnOp.bitNot => "~"  | UnOp.addrOf => "&"
  | UnOp.deref  => "*"  | UnOp.preInc => "++"
  | UnOp.preDec => "--"

private def renderAssignOp : BinOp → String
  | BinOp.add    => "+="  | BinOp.sub    => "-="
  | BinOp.mul    => "*="  | BinOp.div    => "/="
  | BinOp.mod    => "%="
  | BinOp.bitAnd => "&="  | BinOp.bitOr  => "|="
  | BinOp.bitXor => "^="
  | BinOp.shl    => "<<=" | BinOp.shr    => ">>="
  | op           => renderBinOp op ++ "="  -- fallback


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // render expression
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderExpr (expr : CExpr) : String :=
  match expr with
  | CExpr.litInt n  => if n ≥ 0 then toString n else s!"({n})"
  | CExpr.litUInt n suffix => s!"{n}{suffix}"
  | CExpr.litStr s  => s!"\"{escapeStr s}\""
  | CExpr.litBool true  => "true"
  | CExpr.litBool false => "false"

  | CExpr.initList elems =>
    let inner := ", ".intercalate (elems.map renderExpr)
    s!"\{{inner}}"

  | CExpr.var name     => name
  | CExpr.qual ns name => s!"{ns}::{name}"

  | CExpr.field expr name => s!"{renderExpr expr}.{name}"
  | CExpr.arrow expr name => s!"{renderExpr expr}->{name}"
  | CExpr.index expr idx  => s!"{renderExpr expr}[{renderExpr idx}]"

  | CExpr.call fn args =>
    let argStr := ", ".intercalate (args.map renderExpr)
    s!"{fn}({argStr})"

  | CExpr.methodCall expr method args =>
    let argStr := ", ".intercalate (args.map renderExpr)
    s!"{renderExpr expr}.{method}({argStr})"

  | CExpr.binop op lhs rhs =>
    s!"{renderExpr lhs} {renderBinOp op} {renderExpr rhs}"

  | CExpr.unop op operand =>
    s!"{renderUnOp op}{renderExpr operand}"

  | CExpr.cast kind ty expr =>
    s!"{kind}<{renderType ty}>({renderExpr expr})"

  | CExpr.cCast ty expr =>
    s!"({renderType ty}){renderExpr expr}"

  | CExpr.ternary cond thenE elseE =>
    s!"{renderExpr cond} ? {renderExpr thenE} : {renderExpr elseE}"

  | CExpr.sizeofType ty   => s!"sizeof({renderType ty})"
  | CExpr.sizeofExpr expr => s!"sizeof({renderExpr expr})"
  | CExpr.parens inner    => s!"({renderExpr inner})"


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // render statement
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderStmt (stmt : CStmt) (ind : Nat := 0) : String :=
  let p := pad ind
  match stmt with
  | CStmt.expr e => s!"{p}{renderExpr e};"
  | CStmt.decl ty name (Option.some init) =>
    s!"{p}{renderType ty} {name} = {renderExpr init};"
  | CStmt.decl ty name Option.none =>
    s!"{p}{renderType ty} {name};"
  | CStmt.assign lhs rhs =>
    s!"{p}{renderExpr lhs} = {renderExpr rhs};"
  | CStmt.assignOp op lhs rhs =>
    s!"{p}{renderExpr lhs} {renderAssignOp op} {renderExpr rhs};"
  | CStmt.ret value => s!"{p}return {renderExpr value};"
  | CStmt.retVoid   => s!"{p}return;"

  | CStmt.ifElse cond thenBody Option.none =>
    let bodyStr := renderBlock thenBody (ind + 2)
    s!"{p}if ({renderExpr cond}) \{\n{bodyStr}\n{p}}"

  | CStmt.ifElse cond thenBody (Option.some elseBody) =>
    let thenStr := renderBlock thenBody (ind + 2)
    let elseStr := renderBlock elseBody (ind + 2)
    s!"{p}if ({renderExpr cond}) \{\n{thenStr}\n{p}} else \{\n{elseStr}\n{p}}"

  | CStmt.for_ init cond step body =>
    let initStr := match init with
      | CStmt.decl ty name (Option.some e) => s!"{renderType ty} {name} = {renderExpr e}"
      | CStmt.expr e => renderExpr e
      | _ => ""
    let bodyStr := renderBlock body (ind + 2)
    s!"{p}for ({initStr}; {renderExpr cond}; {renderExpr step}) \{\n{bodyStr}\n{p}}"

  | CStmt.rangeFor ty name range body =>
    let bodyStr := renderBlock body (ind + 2)
    s!"{p}for ({renderType ty} {name} : {renderExpr range}) \{\n{bodyStr}\n{p}}"

  | CStmt.while_ cond body =>
    let bodyStr := renderBlock body (ind + 2)
    s!"{p}while ({renderExpr cond}) \{\n{bodyStr}\n{p}}"

  | CStmt.block stmts =>
    let bodyStr := renderBlock stmts (ind + 2)
    s!"{p}\{\n{bodyStr}\n{p}}"

  | CStmt.break    => s!"{p}break;"
  | CStmt.continue => s!"{p}continue;"
  | CStmt.comment text => s!"{p}// {text}"
  | CStmt.blank => ""

where
  /-- render a list of statements as a block body -/
  renderBlock (stmts : List CStmt) (ind : Nat) : String :=
    "\n".intercalate (stmts.map fun s => renderStmt s ind)


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // render declaration
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderDecl (decl : CDecl) (ind : Nat := 0) : String :=
  let p := pad ind
  match decl with
  | CDecl.pragmaOnce => "#pragma once"
  | CDecl.includeSystem header => s!"#include <{header}>"
  | CDecl.includeLocal header  => s!"#include \"{header}\""
  | CDecl.forwardDecl name => s!"{p}struct {name};"

  | CDecl.struct_ name fields =>
    let fieldLines := fields.map fun f =>
      s!"{p}  {renderType f.ty} {f.name};"
    s!"{p}struct {name} \{\n{"\n".intercalate fieldLines}\n{p}};"

  | CDecl.enumClass name underlying values =>
    let underStr := match underlying with
      | Option.some ty => s!" : {renderType ty}"
      | Option.none    => ""
    let valLines := values.map fun (name, init) =>
      match init with
      | Option.some e => s!"{name} = {renderExpr e}"
      | Option.none   => name
    s!"{p}enum class {name}{underStr} \{ {", ".intercalate valLines} };"

  | CDecl.func retType name params body =>
    let paramStr := ", ".intercalate (params.map fun p =>
      s!"{renderType p.ty} {p.name}")
    let bodyStr := "\n".intercalate (body.map fun s => renderStmt s (ind + 2))
    s!"{p}{renderType retType} {name}({paramStr}) \{\n{bodyStr}\n{p}}"

  | CDecl.funcAttr attrs retType name params body =>
    let attrStr := " ".intercalate (attrs.map fun a => s!"[[{a}]]")
    let paramStr := ", ".intercalate (params.map fun p =>
      s!"{renderType p.ty} {p.name}")
    let bodyStr := "\n".intercalate (body.map fun s => renderStmt s (ind + 2))
    s!"{p}{attrStr} {renderType retType} {name}({paramStr}) \{\n{bodyStr}\n{p}}"

  | CDecl.namespace_ name decls =>
    let body := "\n\n".intercalate (decls.map fun d => renderDecl d (ind + 2))
    s!"{p}namespace {name} \{\n\n{body}\n\n{p}} // namespace {name}"

  | CDecl.anonNamespace decls =>
    let body := "\n\n".intercalate (decls.map fun d => renderDecl d (ind + 2))
    s!"{p}namespace \{\n\n{body}\n\n{p}} // anonymous namespace"

  | CDecl.using_ alias ty => s!"{p}using {alias} = {renderType ty};"
  | CDecl.staticAssert cond Option.none =>
    s!"{p}static_assert({renderExpr cond});"
  | CDecl.staticAssert cond (Option.some msg) =>
    s!"{p}static_assert({renderExpr cond}, \"{escapeStr msg}\");"

  | CDecl.comment text => s!"{p}// {text}"
  | CDecl.blank => ""
  | CDecl.raw text => text


/- ════════════════════════════════════════════════════════════════════════════════
                                                               // render file
   ════════════════════════════════════════════════════════════════════════════════ -/

def renderFile (f : CFile) : String :=
  let header := match f.header with
    | Option.none   => ""
    | Option.some h => s!"// {h}\n\n"
  let pragma := if f.pragmaOnce then "#pragma once\n\n" else ""
  let body := "\n\n".intercalate (f.decls.map fun d => renderDecl d)
  header ++ pragma ++ body ++ "\n"


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

-- ── types ─────────────────────────────────────────────────────────────────────

#guard renderType CType.void == "void"
#guard renderType CType.bool == "bool"
#guard renderType CType.u8 == "uint8_t"
#guard renderType CType.u64 == "uint64_t"
#guard renderType CType.i32 == "int32_t"
#guard renderType CType.sizeT == "size_t"
#guard renderType (CType.named "NixString") == "NixString"
#guard renderType (CType.ptr CType.u8) == "uint8_t*"
#guard renderType (CType.const CType.u8) == "const uint8_t"
#guard renderType (CType.constPtr CType.u8) == "const uint8_t*"
#guard renderType (CType.constRef (CType.named "NixString"))
  == "const NixString&"
#guard renderType CType.constByteSpan == "std::span<const uint8_t>"
#guard renderType CType.byteVec == "std::vector<uint8_t>"
#guard renderType (CType.array CType.u8 32) == "std::array<uint8_t, 32>"

-- ── expressions ───────────────────────────────────────────────────────────────

#guard renderExpr (CExpr.litInt 42) == "42"
#guard renderExpr (CExpr.litBool true) == "true"
#guard renderExpr (CExpr.var "buf") == "buf"
#guard renderExpr (CExpr.field (CExpr.var "s") "magic") == "s.magic"
#guard renderExpr (CExpr.index (CExpr.var "buf") (CExpr.litInt 0)) == "buf[0]"
#guard renderExpr (CExpr.call "memcpy" [CExpr.var "dst", CExpr.var "src", CExpr.litInt 8])
  == "memcpy(dst, src, 8)"
#guard renderExpr (CExpr.methodCall (CExpr.var "buf") "size" []) == "buf.size()"
#guard renderExpr (CExpr.binop BinOp.lt (CExpr.var "len") (CExpr.litInt 16))
  == "len < 16"
#guard renderExpr (CExpr.unop UnOp.addrOf (CExpr.field (CExpr.var "s") "magic"))
  == "&s.magic"
#guard renderExpr (CExpr.cast "static_cast" CType.u8 (CExpr.var "x"))
  == "static_cast<uint8_t>(x)"

-- ── statements ────────────────────────────────────────────────────────────────

#guard renderStmt (CStmt.ret (CExpr.litBool false)) == "return false;"
#guard renderStmt (CStmt.retVoid) == "return;"
#guard renderStmt (CStmt.decl CType.u64 "offset" (Option.some (CExpr.litInt 0)))
  == "uint64_t offset = 0;"

-- ── visual: a real codec header ───────────────────────────────────────────────

private def testNarHeader : CFile :=
  let fields : List CField := [⟨CType.u64, "magic"⟩, ⟨CType.u64, "tag_len"⟩]
  let packParams : List CParam :=
    [⟨CType.constRef (CType.named "NarHeader"), "s"⟩,
     ⟨CType.ptr CType.u8, "buf"⟩]
  let parseParams : List CParam := [⟨CType.constByteSpan, "buf"⟩]
  { header := Option.some "Generated by Continuity — do not edit"
  , decls := [
      CDecl.includeSystem "cstdint",
      CDecl.includeSystem "cstring",
      CDecl.includeSystem "span",
      CDecl.includeSystem "optional",
      CDecl.blank,
      CDecl.namespace_ "continuity" [
        CDecl.struct_ "NarHeader" fields,
        CDecl.blank,
        CDecl.staticAssert
          (CExpr.binop BinOp.eq
            (CExpr.sizeofType (CType.named "NarHeader"))
            (CExpr.litInt 16))
          (Option.some "NarHeader must be 16 bytes"),
        CDecl.blank,
        CDecl.func CType.void "pack_NarHeader" packParams
          [CStmt.memcpy (CExpr.addOffset "buf" 0) (CExpr.addrOfField "s" "magic") 8,
           CStmt.memcpy (CExpr.addOffset "buf" 8) (CExpr.addrOfField "s" "tag_len") 8],
        CDecl.blank,
        CDecl.func (CType.optional (CType.named "NarHeader")) "parse_NarHeader" parseParams
          [CStmt.sizeCheck (CExpr.methodCall (CExpr.var "buf") "size" []) 16,
           CStmt.decl (CType.named "NarHeader") "out" Option.none,
           CStmt.memcpy (CExpr.addrOfField "out" "magic") (CExpr.methodCall (CExpr.var "buf") "data" []) 8,
           CStmt.memcpy (CExpr.addrOfField "out" "tag_len")
             (CExpr.binop BinOp.add (CExpr.methodCall (CExpr.var "buf") "data" []) (CExpr.litInt 8)) 8,
           CStmt.ret (CExpr.var "out")]
      ]
    ]
  }

#eval renderFile testNarHeader


end Continuity.Emit.Cpp
