import Continuity.Codegen.AST.Dhall.Ast

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "They set a slamhound on Turner's trail in New Delhi, slotted it to
      his pheromones and the color of his hair. It caught the scent of him
      first in the crowded streets near Connaught Place, locked onto his
      thermal ghost threading between the rickshaws and the white
      Ambassador cars, and began to render. Layer by layer it peeled the
      city apart — the smells, the heat signatures, the reflected
      fluorescence — until only the target remained, a single irreducible
      shape stripped of every context except the one the hound was built
      to recognize."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Dhall

/-
  `Dhall` renderer — the ONLY place `Dhall` text is assembled.

  One function: `render`. Everything else is a helper called by `render`.
  Generated files should be parseable by `dhall format` without changes.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // helpers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def pad (n : Nat) : String := "".pushn ' ' n

-- escape a string for `Dhall` double-quoted text
private def escapeText (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '"'  => acc ++ "\\\""
    | '\n' => acc ++ "\\n"
    | '\t' => acc ++ "\\t"
    | '$'  => acc ++ "\\u0024"
    | c    => acc.push c
  ) ""

-- render a binary operator to its `Dhall` symbol
private def renderBinOp : BinOp → String
  | BinOp.equiv        => "==="
  | BinOp.prefer       => "//"
  | BinOp.combine      => "/\\\\"
  | BinOp.combineTypes => "∧"
  | BinOp.listAppend   => "#"
  | BinOp.textAppend   => "++"
  | BinOp.boolOr       => "||"
  | BinOp.boolAnd      => "&&"
  | BinOp.boolEq       => "=="
  | BinOp.boolNe       => "!="
  | BinOp.natPlus      => "+"
  | BinOp.natTimes     => "*"

-- render an import reference
private def renderImport : Import → String
  | Import.file path       => s!"./{path}"
  | Import.parentFile path => s!"../{path}"
  | Import.absFile path    => s!"/{path}"
  | Import.homeFile path   => s!"~/{path}"
  | Import.env name        => s!"env:{name}"
  | Import.missing         => "missing"

-- render import mode suffix
private def renderImportMode : ImportMode → String
  | ImportMode.code       => ""
  | ImportMode.asText     => " as Text"
  | ImportMode.asBytes    => " as Bytes"
  | ImportMode.asLocation => " as Location"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // render
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

partial def render (e : Expr) (indent : Nat := 0) : String :=
  match e with

  -- literals

  | Expr.bool true  => "True"
  | Expr.bool false => "False"
  | Expr.natural n  => toString n
  | Expr.integer i  => if i ≥ 0 then s!"+{i}" else toString i
  | Expr.text s     => s!"\"{escapeText s}\""

  | Expr.interpolation texts exprs =>
    let pairs := texts.zip (exprs.map (fun e => render e indent) ++ [""])
    let inner := pairs.foldl (fun acc (t, e) =>
      if e == "" then acc ++ escapeText t
      else acc ++ escapeText t ++ "${" ++ e ++ "}"
    ) ""
    s!"\"{inner}\""

  | Expr.textBlock texts exprs =>
    let pairs := texts.zip (exprs.map (fun e => render e indent) ++ [""])
    let inner := pairs.foldl (fun acc (t, e) =>
      if e == "" then acc ++ t
      else acc ++ t ++ "${" ++ e ++ "}"
    ) ""
    "''\n" ++ inner ++ "\n''"

  -- references

  | Expr.var name => name

  | Expr.import_ ref mode Option.none =>
    renderImport ref ++ renderImportMode mode

  | Expr.import_ ref mode (Option.some hash) =>
    renderImport ref ++ " sha256:" ++ hash ++ renderImportMode mode

  -- collections

  | Expr.list [] (Option.some ty) => s!"[] : {render ty indent}"
  | Expr.list [] Option.none      => "[] : List {}"
  | Expr.list elements _ =>
    let inner := ", ".intercalate (elements.map (fun e => render e indent))
    s!"[ {inner} ]"

  -- records

  | Expr.record [] => "{=}"

  | Expr.record [field] =>
    s!"\{ {field.1} = {render field.2 indent} }"

  | Expr.record (first :: rest) =>
    let ind := pad indent
    let deeper := indent + 2
    let firstLine := s!"\{ {first.1} = {render first.2 deeper}"
    let restLines := rest.map fun (name, value) =>
      s!"{ind}, {name} = {render value deeper}"
    let closeLine := s!"{ind}}"
    "\n".intercalate ([firstLine] ++ restLines ++ [closeLine])

  | Expr.recordType [] => "{}"

  | Expr.recordType (first :: rest) =>
    let ind := pad indent
    let firstLine := s!"\{ {first.1} : {render first.2 indent}"
    let restLines := rest.map fun (name, ty) =>
      s!"{ind}, {name} : {render ty indent}"
    let closeLine := s!"{ind}}"
    "\n".intercalate ([firstLine] ++ restLines ++ [closeLine])

  | Expr.field expr name => s!"{render expr indent}.{name}"

  | Expr.project expr fieldNames =>
    let inner := ", ".intercalate fieldNames
    s!"{render expr indent}.\{ {inner} }"

  | Expr.projectType expr ty =>
    s!"{render expr indent}.({render ty indent})"

  -- unions

  | Expr.unionType alts =>
    let inner := " | ".intercalate (alts.map fun (name, payload) =>
      match payload with
      | Option.none    => name
      | Option.some ty => s!"{name} : {render ty indent}")
    s!"< {inner} >"

  | Expr.unionVal _typeName alts tag Option.none =>
    let unionStr := render (Expr.unionType alts) indent
    s!"{unionStr}.{tag}"

  | Expr.unionVal _typeName alts tag (Option.some value) =>
    let unionStr := render (Expr.unionType alts) indent
    s!"{unionStr}.{tag} {render value indent}"

  -- functions

  | Expr.lambda param paramType body =>
    s!"λ({param} : {render paramType indent}) → {render body indent}"

  | Expr.forallE "_" paramType body =>
    -- non-dependent function type: render as `A → B`
    s!"{render paramType indent} → {render body indent}"

  | Expr.forallE param paramType body =>
    s!"∀({param} : {render paramType indent}) → {render body indent}"

  | Expr.app fn arg =>
    let argStr := match arg with
      | Expr.app _ _ => s!"({render arg indent})"
      | Expr.binop _ _ _ => s!"({render arg indent})"
      | _ => render arg indent
    s!"{render fn indent} {argStr}"

  -- binding

  | Expr.letIn name Option.none value body =>
    let ind := pad indent
    s!"let {name} = {render value (indent + 6 + name.length)}\n{ind}\n{ind}in  {render body indent}"

  | Expr.letIn name (Option.some ty) value body =>
    let ind := pad indent
    s!"let {name} : {render ty indent} = {render value (indent + 6 + name.length)}\n{ind}\n{ind}in  {render body indent}"

  | Expr.ite cond thenBranch elseBranch =>
    s!"if {render cond indent} then {render thenBranch indent} else {render elseBranch indent}"

  -- operators

  | Expr.binop op lhs rhs =>
    s!"{render lhs indent} {renderBinOp op} {render rhs indent}"

  | Expr.completion ty value =>
    s!"{render ty indent}::{render value indent}"

  | Expr.with expr path value =>
    let pathStr := ".".intercalate path
    s!"{render expr indent} with {pathStr} = {render value indent}"

  -- annotation

  | Expr.annot expr ty => s!"{render expr indent} : {render ty indent}"

  -- optional

  | Expr.some value => s!"Some {render value indent}"
  | Expr.none ty    => s!"None {render ty indent}"

  -- builtins

  | Expr.builtin name => name

  -- special forms

  | Expr.merge handler union Option.none =>
    s!"merge {render handler indent} {render union indent}"

  | Expr.merge handler union (Option.some ty) =>
    s!"merge {render handler indent} {render union indent} : {render ty indent}"

  | Expr.toMap expr Option.none =>
    s!"toMap {render expr indent}"

  | Expr.toMap expr (Option.some ty) =>
    s!"toMap {render expr indent} : {render ty indent}"

  | Expr.assert annot =>
    s!"assert : {render annot indent}"

  -- metadata

  | Expr.comment text body =>
    let ind := pad indent
    s!"{ind}\{- {text} -}\n{render body indent}"


--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // module // render
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def renderModule (m : Module) : String :=
  let header := match m.header with
    | Option.none   => ""
    | Option.some h => s!"\{- {h} -}\n\n"
  header ++ render m.body

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                       // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- regression tests. every constructor gets at least one `#guard`.

-- literals

#guard render (Expr.bool true)       == "True"
#guard render (Expr.bool false)      == "False"
#guard render (Expr.natural 0)       == "0"
#guard render (Expr.natural 42)      == "42"
#guard render (Expr.integer 3)       == "+3"
#guard render (Expr.integer (-7))    == "-7"
#guard render (Expr.text "hello")    == "\"hello\""
#guard render (Expr.text "say \"hi\"") == "\"say \\\"hi\\\"\""
#guard render (Expr.var "x")         == "x"
#guard render (Expr.builtin "Natural") == "Natural"

-- collections

#guard render (Expr.list [] (Option.some (Expr.builtin "Natural"))) == "[] : Natural"
#guard render (Expr.list [Expr.natural 1, Expr.natural 2] Option.none) == "[ 1, 2 ]"

-- records

#guard render (Expr.record []) == "{=}"
#guard render (Expr.record [("name", Expr.text "foo")]) == "{ name = \"foo\" }"

-- unions

#guard render (Expr.unionType [("x86_64", Option.none), ("aarch64", Option.none)])
  == "< x86_64 | aarch64 >"

-- optional

#guard render (Expr.some (Expr.natural 42)) == "Some 42"
#guard render (Expr.none (Expr.builtin "Natural")) == "None Natural"

-- lambda / forall

#guard render (Expr.lambda "x" (Expr.builtin "Natural") (Expr.var "x"))
  == "λ(x : Natural) → x"
#guard render (Expr.forallE "x" (Expr.builtin "Natural") (Expr.builtin "Bool"))
  == "∀(x : Natural) → Bool"
-- non-dependent arrow
#guard render (Expr.arrow (Expr.builtin "Natural") (Expr.builtin "Bool"))
  == "Natural → Bool"

-- application

#guard render (Expr.app (Expr.var "f") (Expr.var "x")) == "f x"

-- annotation

#guard render (Expr.annot (Expr.natural 42) (Expr.builtin "Natural"))
  == "42 : Natural"

-- if/then/else

#guard render (Expr.ite (Expr.var "debug") (Expr.text "-O0") (Expr.text "-O2"))
  == "if debug then \"-O0\" else \"-O2\""

-- operators

#guard render (Expr.binop BinOp.prefer (Expr.var "defaults") (Expr.var "overrides"))
  == "defaults // overrides"
#guard render (Expr.binop BinOp.listAppend (Expr.var "base") (Expr.var "extra"))
  == "base # extra"
#guard render (Expr.binop BinOp.textAppend (Expr.text "hello ") (Expr.var "name"))
  == "\"hello \" ++ name"
#guard render (Expr.binop BinOp.natPlus (Expr.natural 1) (Expr.natural 2))
  == "1 + 2"

-- with

#guard render (Expr.with (Expr.var "config") ["compiler", "flags"] (Expr.var "newFlags"))
  == "config with compiler.flags = newFlags"

-- completion

#guard render (Expr.completion (Expr.var "Config") (Expr.var "myConfig"))
  == "Config::myConfig"

-- imports

#guard render (Expr.importFile "prelude/Types.dhall") == "./prelude/Types.dhall"
#guard render (Expr.importFileAsText "scripts/build.sh")
  == "./scripts/build.sh as Text"
#guard render (Expr.importEnv "HOME") == "env:HOME"

-- merge

#guard render (Expr.merge (Expr.var "handler") (Expr.var "input") Option.none)
  == "merge handler input"

-- toMap

#guard render (Expr.toMap (Expr.var "envVars") Option.none)
  == "toMap envVars"

-- assert

#guard render (Expr.assert (Expr.binop BinOp.equiv (Expr.natural 1) (Expr.natural 1)))
  == "assert : 1 === 1"

-- projection

#guard render (Expr.project (Expr.var "config") ["arch", "os"])
  == "config.{ arch, os }"

-- combinators

#guard render (Expr.nat 7)     == "7"
#guard render (Expr.str "hi")  == "\"hi\""
#guard render (Expr.tt)        == "True"
#guard render (Expr.ff)        == "False"
#guard render (Expr.ty "Text") == "Text"

-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

end Continuity.Codegen.AST.Dhall
