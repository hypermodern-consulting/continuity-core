import Continuity.Emit.Haskell.Ast

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // emit // haskell
                                                                    render.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Haskell renderer — the ONLY place Haskell text is assembled.

  Five render functions, one per syntactic category:
    renderType, renderPat, renderExpr, renderDoStmt, renderDecl

  renderExpr and renderDoStmt are mutually recursive (do-blocks contain
  expressions, expressions contain do-blocks).

  All indentation is explicit — the `ind` parameter tracks the current
  column. Haskell's layout rule means wrong indentation produces wrong
  programs, not just ugly ones.
-/

namespace Continuity.Emit.Haskell


/- ════════════════════════════════════════════════════════════════════════════════
                                                                     // helpers
   ════════════════════════════════════════════════════════════════════════════════ -/

private def pad (n : Nat) : String := "".pushn ' ' n

private def escapeStr (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '"'  => acc ++ "\\\""
    | '\n' => acc ++ "\\n"
    | '\t' => acc ++ "\\t"
    | c    => acc.push c
  ) ""

private def escapeChar (c : Char) : String :=
  match c with
  | '\\' => "\\\\"
  | '\'' => "\\'"
  | '\n' => "\\n"
  | '\t' => "\\t"
  | c    => String.singleton c


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // render type
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderType (ty : HsType) : String :=
  match ty with
  | HsType.con name          => name
  | HsType.qual modName name => s!"{modName}.{name}"
  | HsType.var name          => name
  | HsType.unit              => "()"

  | HsType.app fn arg =>
    let argStr := match arg with
      | HsType.app _ _   => s!"({renderType arg})"
      | HsType.arrow _ _ => s!"({renderType arg})"
      | _                 => renderType arg
    s!"{renderType fn} {argStr}"

  | HsType.arrow domain codomain =>
    let domStr := match domain with
      | HsType.arrow _ _ => s!"({renderType domain})"
      | _                 => renderType domain
    s!"{domStr} -> {renderType codomain}"

  | HsType.list elem   => s!"[{renderType elem}]"
  | HsType.tuple elems => "(" ++ ", ".intercalate (elems.map renderType) ++ ")"

  | HsType.constrained constraints body =>
    let ctxStr := match constraints with
      | [single] => renderType single
      | many     => "(" ++ ", ".intercalate (many.map renderType) ++ ")"
    s!"{ctxStr} => {renderType body}"

  | HsType.forallT vars body =>
    s!"forall {" ".intercalate vars}. {renderType body}"

  | HsType.promotedList elems =>
    "'[" ++ ", ".intercalate (elems.map renderType) ++ "]"

  | HsType.parens inner   => s!"({renderType inner})"
  | HsType.infixT op l r  => s!"{renderType l} {op} {renderType r}"
  | HsType.stringT value  => s!"\"{escapeStr value}\""


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // render pattern
   ════════════════════════════════════════════════════════════════════════════════ -/

partial def renderPat (pat : HsPat) : String :=
  match pat with
  | HsPat.var name    => name
  | HsPat.wild        => "_"
  | HsPat.litInt n    => if n ≥ 0 then toString n else s!"({n})"
  | HsPat.litStr s    => s!"\"{escapeStr s}\""
  | HsPat.parens inner => s!"({renderPat inner})"
  | HsPat.bang inner  => s!"!{renderPat inner}"

  | HsPat.con name [] => name
  | HsPat.con name args =>
    let argsStr := " ".intercalate (args.map fun a =>
      match a with
      | HsPat.con _ (_ :: _) => s!"({renderPat a})"
      | _ => renderPat a)
    s!"{name} {argsStr}"

  | HsPat.as name inner => s!"{name}@({renderPat inner})"
  | HsPat.tuple elems   => "(" ++ ", ".intercalate (elems.map renderPat) ++ ")"
  | HsPat.listPat elems => "[" ++ ", ".intercalate (elems.map renderPat) ++ "]"

  | HsPat.record con fields =>
    let fs := fields.map fun (name, pat) => s!"{name} = {renderPat pat}"
    s!"{con} \{ {", ".intercalate fs} }"


/- ════════════════════════════════════════════════════════════════════════════════
                                                // render expression + do-stmts
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! renderExpr and renderDoStmt are mutually recursive. -/

mutual

partial def renderExpr (expr : HsExpr) (ind : Nat := 0) : String :=
  match expr with

  -- ── literals ──────────────────────────────────────────────────────────────

  | HsExpr.litInt n  => if n ≥ 0 then toString n else s!"({n})"
  | HsExpr.litStr s  => s!"\"{escapeStr s}\""
  | HsExpr.litChar c => s!"'{escapeChar c}'"
  | HsExpr.unit      => "()"

  | HsExpr.list elems =>
    "[" ++ ", ".intercalate (elems.map fun e => renderExpr e ind) ++ "]"

  | HsExpr.tuple elems =>
    "(" ++ ", ".intercalate (elems.map fun e => renderExpr e ind) ++ ")"

  -- ── references ────────────────────────────────────────────────────────────

  | HsExpr.var name          => name
  | HsExpr.con name          => name
  | HsExpr.qual modName name => s!"{modName}.{name}"

  -- ── application ───────────────────────────────────────────────────────────

  | HsExpr.app fn arg =>
    let argStr := match arg with
      | HsExpr.app _ _      => s!"({renderExpr arg ind})"
      | HsExpr.infix_ _ _ _ => s!"({renderExpr arg ind})"
      | HsExpr.typed _ _    => s!"({renderExpr arg ind})"
      | _                    => renderExpr arg ind
    s!"{renderExpr fn ind} {argStr}"

  | HsExpr.infix_ op lhs rhs =>
    s!"{renderExpr lhs ind} {op} {renderExpr rhs ind}"

  | HsExpr.section op side true =>
    -- left section: `(x +)`
    s!"({renderExpr side ind} {op})"

  | HsExpr.section op side false =>
    -- right section: `(+ x)`
    s!"({op} {renderExpr side ind})"

  -- ── lambda ────────────────────────────────────────────────────────────────

  | HsExpr.lam params body =>
    let ps := " ".intercalate (params.map renderPat)
    s!"\\{ps} -> {renderExpr body ind}"

  -- ── binding ───────────────────────────────────────────────────────────────

  | HsExpr.letIn bindings body =>
    let bindInd := pad (ind + 4)
    let bs := bindings.map fun (pat, expr) =>
      s!"{bindInd}{renderPat pat} = {renderExpr expr (ind + 4)}"
    let header := s!"let\n{"\n".intercalate bs}"
    s!"{header}\n{pad ind}in {renderExpr body ind}"

  | HsExpr.ite cond thn els =>
    s!"if {renderExpr cond ind} then {renderExpr thn ind} else {renderExpr els ind}"

  | HsExpr.case_ scrut alts =>
    let altInd := ind + 2
    let altLines := alts.map fun (pat, body) =>
      s!"{pad altInd}{renderPat pat} -> {renderExpr body altInd}"
    s!"case {renderExpr scrut ind} of\n{"\n".intercalate altLines}"

  -- ── do-notation ───────────────────────────────────────────────────────────

  | HsExpr.do_ stmts =>
    let stmtInd := ind + 2
    let stmtLines := stmts.map fun s => s!"{pad stmtInd}{renderDoStmt s stmtInd}"
    s!"do\n{"\n".intercalate stmtLines}"

  -- ── type annotation ───────────────────────────────────────────────────────

  | HsExpr.typed expr ty => s!"{renderExpr expr ind} :: {renderType ty}"

  -- ── record ────────────────────────────────────────────────────────────────

  | HsExpr.recordCon con fields =>
    let fs := fields.map fun (name, expr) => s!"{name} = {renderExpr expr ind}"
    s!"{con} \{ {", ".intercalate fs} }"

  | HsExpr.recordUpdate expr fields =>
    let fs := fields.map fun (name, e) => s!"{name} = {renderExpr e ind}"
    s!"{renderExpr expr ind} \{ {", ".intercalate fs} }"

  -- ── other ─────────────────────────────────────────────────────────────────

  | HsExpr.parens inner => s!"({renderExpr inner ind})"
  | HsExpr.negate inner => s!"-{renderExpr inner ind}"

partial def renderDoStmt (stmt : DoStmt) (ind : Nat) : String :=
  match stmt with
  | DoStmt.bind pat expr  => s!"{renderPat pat} <- {renderExpr expr ind}"
  | DoStmt.letStmt pat expr => s!"let {renderPat pat} = {renderExpr expr (ind + 4)}"
  | DoStmt.expr e         => renderExpr e ind

end


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // render declaration
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- render a data constructor -/
private def renderDataCon (dc : DataCon) : String :=
  match dc with
  | DataCon.positional name [] => name
  | DataCon.positional name fields =>
    s!"{name} {" ".intercalate (fields.map renderType)}"
  | DataCon.record name fields =>
    let fs := fields.map fun (n, t) => s!"{n} :: {renderType t}"
    s!"{name}\n    \{ {"\n    , ".intercalate fs}\n    }"

/-- render a function clause (patterns + rhs + where) -/
private def renderClause (name : String) (clause : FunClause) : String :=
  let lhs := if clause.patterns.isEmpty
    then name
    else
      let renderedPats := clause.patterns.map fun p =>
        match p with
        | HsPat.con _ (_ :: _) => s!"({renderPat p})"
        | _ => renderPat p
      s!"{name} {" ".intercalate renderedPats}"
  let rhsStr := match clause.rhs with
    | RHS.simple body => s!" = {renderExpr body 2}"
    | RHS.guarded guards =>
      let gs := guards.map fun (cond, body) =>
        s!"\n  | {renderExpr cond 4} = {renderExpr body 4}"
      "".intercalate gs
  let whereStr := if clause.whereBinds.isEmpty then ""
    else
      let ws := clause.whereBinds.map fun (n, e) =>
        s!"    {n} = {renderExpr e 4}"
      s!"\n  where\n{"\n".intercalate ws}"
  lhs ++ rhsStr ++ whereStr

partial def renderDecl (decl : HsDecl) : String :=
  match decl with

  | HsDecl.pragma kind value =>
    s!"\{-# {kind} {value} #-}"

  | HsDecl.import_ modName qualified alias spec =>
    let qualStr := if qualified then "qualified " else ""
    let aliasStr := match alias with
      | Option.some a => s!" as {a}"
      | Option.none   => ""
    let specStr := match spec with
      | ImportSpec.all => ""
      | ImportSpec.only names  => s!" ({", ".intercalate names})"
      | ImportSpec.hiding names => s!" hiding ({", ".intercalate names})"
    s!"import {qualStr}{modName}{aliasStr}{specStr}"

  | HsDecl.typeSig name ty =>
    s!"{name} :: {renderType ty}"

  | HsDecl.funDef name clauses =>
    "\n".intercalate (clauses.map (renderClause name))

  | HsDecl.dataDef name params constructors deriving_ =>
    let paramStr := if params.isEmpty then "" else s!" {" ".intercalate params}"
    let consStr := match constructors with
      | [] => ""
      | first :: rest =>
        let firstStr := s!"\n  = {renderDataCon first}"
        let restStr := rest.map fun c => s!"\n  | {renderDataCon c}"
        firstStr ++ "".intercalate restStr
    let derivStr := if deriving_.isEmpty then ""
      else s!"\n  deriving ({", ".intercalate deriving_})"
    s!"data {name}{paramStr}{consStr}{derivStr}"

  | HsDecl.newtypeDef name params con deriving_ =>
    let paramStr := if params.isEmpty then "" else s!" {" ".intercalate params}"
    let derivStr := if deriving_.isEmpty then ""
      else s!" deriving ({", ".intercalate deriving_})"
    s!"newtype {name}{paramStr} = {renderDataCon con}{derivStr}"

  | HsDecl.typeAlias name params body =>
    let paramStr := if params.isEmpty then "" else s!" {" ".intercalate params}"
    s!"type {name}{paramStr} = {renderType body}"

  | HsDecl.instanceDef constraints head methods =>
    let ctxStr := match constraints with
      | []       => ""
      | [single] => s!"{renderType single} => "
      | many     => "(" ++ ", ".intercalate (many.map renderType) ++ ") => "
    let methodLines := methods.map fun (name, clauses) =>
      clauses.map (fun c => s!"  {renderClause name c}")
    let body := "\n".intercalate (methodLines.flatten)
    s!"instance {ctxStr}{renderType head} where\n{body}"

  | HsDecl.comment text => s!"-- {text}"
  | HsDecl.blank        => ""


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // render module
   ════════════════════════════════════════════════════════════════════════════════ -/

def renderModule (m : HsModule) : String :=
  -- split declarations into pragmas, imports, and everything else
  let pragmas := m.decls.filter fun d => match d with
    | HsDecl.pragma _ _ => true | _ => false
  let imports := m.decls.filter fun d => match d with
    | HsDecl.import_ _ _ _ _ => true | _ => false
  let body := m.decls.filter fun d => match d with
    | HsDecl.pragma _ _ => false
    | HsDecl.import_ _ _ _ _ => false
    | _ => true

  let pragmaBlock := "\n".intercalate (pragmas.map renderDecl)
  let exportStr := match m.exports with
    | Option.none       => ""
    | Option.some names =>
      let inner := names.map fun n => s!"\n    {n}"
      s!" ({",".intercalate inner}\n  )"
  let moduleDecl := s!"module {m.name}{exportStr} where"
  let importBlock := "\n".intercalate (imports.map renderDecl)
  let bodyBlock := "\n".intercalate (body.map renderDecl)

  let sections := [pragmaBlock, moduleDecl, importBlock, bodyBlock].filter (· ≠ "")
  "\n\n".intercalate sections ++ "\n"


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! regression tests — every major render function gets coverage. -/

-- ── types ─────────────────────────────────────────────────────────────────────

#guard renderType (HsType.con "Int") == "Int"
#guard renderType (HsType.var "a") == "a"
#guard renderType (HsType.unit) == "()"
#guard renderType (HsType.list (HsType.con "Int")) == "[Int]"
#guard renderType (HsType.tuple [HsType.con "Int", HsType.con "Bool"]) == "(Int, Bool)"
#guard renderType (HsType.arrow (HsType.con "Int") (HsType.con "Bool")) == "Int -> Bool"
#guard renderType (HsType.app (HsType.con "Maybe") (HsType.con "Int")) == "Maybe Int"
#guard renderType (HsType.app (HsType.con "Get") (HsType.con "NixString")) == "Get NixString"

-- parenthesization of arrow in app argument
#guard renderType (HsType.app (HsType.con "IO")
  (HsType.arrow (HsType.con "Int") (HsType.con "Bool")))
  == "IO (Int -> Bool)"

-- constrained
#guard renderType (HsType.constrained
  [HsType.app (HsType.con "Show") (HsType.var "a")]
  (HsType.arrow (HsType.var "a") (HsType.con "String")))
  == "Show a => a -> String"

-- forall
#guard renderType (HsType.forallT ["a", "b"]
  (HsType.arrow (HsType.var "a") (HsType.var "b")))
  == "forall a b. a -> b"

-- promoted list (graded monad grades)
#guard renderType (HsType.promotedList
  [HsType.con "GLNet", HsType.con "GLCrypto"])
  == "'[GLNet, GLCrypto]"

-- ── patterns ──────────────────────────────────────────────────────────────────

#guard renderPat (HsPat.var "x") == "x"
#guard renderPat (HsPat.wild) == "_"
#guard renderPat (HsPat.con "Just" [HsPat.var "x"]) == "Just x"
#guard renderPat (HsPat.con "NixString" [HsPat.var "content"]) == "NixString content"
#guard renderPat (HsPat.tuple [HsPat.var "a", HsPat.var "b"]) == "(a, b)"
#guard renderPat (HsPat.bang (HsPat.var "x")) == "!x"

-- ── expressions ───────────────────────────────────────────────────────────────

#guard renderExpr (HsExpr.litInt 42) == "42"
#guard renderExpr (HsExpr.litStr "hello") == "\"hello\""
#guard renderExpr (HsExpr.var "x") == "x"
#guard renderExpr (HsExpr.con "True") == "True"
#guard renderExpr (HsExpr.qual "BS" "length") == "BS.length"
#guard renderExpr (HsExpr.app (HsExpr.var "f") (HsExpr.var "x")) == "f x"
#guard renderExpr (HsExpr.infix_ "+" (HsExpr.var "x") (HsExpr.var "y")) == "x + y"
#guard renderExpr (HsExpr.lam [HsPat.var "x"] (HsExpr.var "x")) == "\\x -> x"

#guard renderExpr (HsExpr.ite (HsExpr.var "b")
  (HsExpr.litInt 1) (HsExpr.litInt 0))
  == "if b then 1 else 0"

-- ── declarations ──────────────────────────────────────────────────────────────

#guard renderDecl (HsDecl.pragma "LANGUAGE" "StrictData")
  == "{-# LANGUAGE StrictData #-}"

#guard renderDecl (HsDecl.importOnly "Data.Word" ["Word8", "Word32", "Word64"])
  == "import Data.Word (Word8, Word32, Word64)"

#guard renderDecl (HsDecl.importQualified "Data.ByteString" "BS")
  == "import qualified Data.ByteString as BS"

#guard renderDecl (HsDecl.typeSig "foo"
  (HsType.arrow (HsType.con "Int") (HsType.con "Bool")))
  == "foo :: Int -> Bool"

-- ── visual: a real codec module ───────────────────────────────────────────────

#eval renderModule {
  name := "Continuity.Codec.U32LE"
  exports := Option.some ["U32LE(..)", "parseU32LE", "serializeU32LE"]
  decls := [
    HsDecl.pragma "LANGUAGE" "StrictData",
    HsDecl.blank,
    HsDecl.importOnly "Data.Word" ["Word32"],
    HsDecl.importOnly "Data.Binary.Get" ["Get", "getWord32le"],
    HsDecl.importOnly "Data.Binary.Put" ["Put", "putWord32le"],
    HsDecl.blank,
    HsDecl.newtypeDef "U32LE" [] (DataCon.positional "U32LE" [HsType.con "Word32"]) ["Show", "Eq"],
    HsDecl.blank,
    HsDecl.typeSig "parseU32LE" (HsType.app (HsType.con "Get") (HsType.con "U32LE")),
    HsDecl.simpleFun "parseU32LE" []
      (HsExpr.do_ [
        DoStmt.bind (HsPat.var "w") (HsExpr.var "getWord32le"),
        DoStmt.expr (HsExpr.app (HsExpr.var "pure") (HsExpr.app (HsExpr.con "U32LE") (HsExpr.var "w")))
      ]),
    HsDecl.blank,
    HsDecl.typeSig "serializeU32LE"
      (HsType.arrow (HsType.con "U32LE") (HsType.con "Put")),
    HsDecl.simpleFun "serializeU32LE"
      [HsPat.con "U32LE" [HsPat.var "w"]]
      (HsExpr.app (HsExpr.var "putWord32le") (HsExpr.var "w"))
  ]
}


end Continuity.Emit.Haskell
