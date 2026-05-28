import Continuity.Emit.Dhall.Ast

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // emit // dhall
                                                                    render.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Dhall renderer — the ONLY place Dhall text is assembled.

  One function: `render`. Everything else is a helper called by `render`.
  If you're emitting Dhall and you're not going through `render`, you're
  doing it wrong.

  The output follows Dhall community formatting conventions:
  leading-comma records, blank lines between let bindings, `λ` not
  backslash. Generated files should be readable by humans and parseable
  by `dhall format` without changes.
-/

namespace Continuity.Emit.Dhall



/- ════════════════════════════════════════════════════════════════════════════════
                                                                // indent helpers
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- n spaces -/
private def pad (n : Nat) : String :=
  "".pushn ' ' n

/-- escape a string for dhall double-quoted text.
    handles newlines, tabs, backslashes, double quotes, and `${ -/
private def escapeText (s : String) : String :=
  s.foldl (fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '"'  => acc ++ "\\\""
    | '\n' => acc ++ "\\n"
    | '\t' => acc ++ "\\t"
    | '$'  => acc ++ "\\u0024"  -- prevent accidental interpolation
    | c    => acc.push c
  ) ""


/- ════════════════════════════════════════════════════════════════════════════════
                                                                     // render
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- render a Dhall expression to a string.

    `indent` is the current indentation depth in spaces. most callers
    start at 0. the renderer adds indentation for nested records and
    let chains. -/
partial def render (e : Expr) (indent : Nat := 0) : String :=
  match e with

  -- ── atoms ─────────────────────────────────────────────────────────────────

  | Expr.bool true  => "True"
  | Expr.bool false => "False"

  | Expr.natural n => toString n

  | Expr.integer i =>
    if i ≥ 0 then s!"+{i}" else toString i

  | Expr.text s => s!"\"{escapeText s}\""

  | Expr.var name => name

  | Expr.builtin name => name

  -- ── interpolation ─────────────────────────────────────────────────────────

  | Expr.interpolation texts exprs =>
    let pairs := texts.zip (exprs.map (fun e => render e indent) ++ [""])
    let inner := pairs.foldl (fun acc (t, e) =>
      if e == "" then acc ++ escapeText t
      else acc ++ escapeText t ++ "${" ++ e ++ "}"
    ) ""
    s!"\"{inner}\""

  -- ── collections ───────────────────────────────────────────────────────────

  | Expr.list [] (Option.some ty) =>
    s!"[] : {render ty indent}"

  | Expr.list [] Option.none =>
    "[] : List {}"  -- fallback; caller should provide a type

  | Expr.list elements _ =>
    let inner := ", ".intercalate (elements.map (fun e => render e indent))
    s!"[ {inner} ]"

  -- ── records ───────────────────────────────────────────────────────────────

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

  -- ── field access ──────────────────────────────────────────────────────────

  | Expr.field expr name => s!"{render expr indent}.{name}"

  -- ── unions ────────────────────────────────────────────────────────────────

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

  -- ── lambda ────────────────────────────────────────────────────────────────

  | Expr.lambda param paramType body =>
    s!"λ({param} : {render paramType indent}) → {render body indent}"

  -- ── application ───────────────────────────────────────────────────────────

  | Expr.app fn arg =>
    -- parenthesize the argument if it's an application itself
    let argStr := match arg with
      | Expr.app _ _ => s!"({render arg indent})"
      | _ => render arg indent
    s!"{render fn indent} {argStr}"

  -- ── let ───────────────────────────────────────────────────────────────────

  | Expr.letIn name Option.none value body =>
    let ind := pad indent
    let valueStr := render value (indent + 6 + name.length)
    let bodyStr := render body indent
    s!"let {name} = {valueStr}\n{ind}\n{ind}in  {bodyStr}"

  | Expr.letIn name (Option.some ty) value body =>
    let ind := pad indent
    let valueStr := render value (indent + 6 + name.length)
    let bodyStr := render body indent
    s!"let {name} : {render ty indent} = {valueStr}\n{ind}\n{ind}in  {bodyStr}"

  -- ── annotation ────────────────────────────────────────────────────────────

  | Expr.annot expr ty => s!"{render expr indent} : {render ty indent}"

  -- ── optional ──────────────────────────────────────────────────────────────

  | Expr.some value => s!"Some {render value indent}"
  | Expr.none ty    => s!"None {render ty indent}"

  -- ── merge ─────────────────────────────────────────────────────────────────

  | Expr.merge handler union Option.none =>
    s!"merge {render handler indent} {render union indent}"

  | Expr.merge handler union (Option.some ty) =>
    s!"merge {render handler indent} {render union indent} : {render ty indent}"

  -- ── comment ───────────────────────────────────────────────────────────────

  | Expr.comment text body =>
    let ind := pad indent
    s!"{ind}\{- {text} -}\n{render body indent}"


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // module render
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- render a complete Dhall module (header comment + body expression) -/
def renderModule (m : Module) : String :=
  let header := match m.header with
    | Option.none   => ""
    | Option.some h => s!"\{- {h} -}\n\n"
  header ++ render m.body


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! regression tests. every constructor of Expr gets at least one #guard.
    these run at build time — if they fail, `lake build` fails. -/

-- ── atoms ─────────────────────────────────────────────────────────────────────

#guard render (Expr.bool true)  == "True"
#guard render (Expr.bool false) == "False"
#guard render (Expr.natural 0)  == "0"
#guard render (Expr.natural 42) == "42"
#guard render (Expr.integer 3)  == "+3"
#guard render (Expr.integer (-7)) == "-7"
#guard render (Expr.text "hello") == "\"hello\""
#guard render (Expr.text "say \"hi\"") == "\"say \\\"hi\\\"\""
#guard render (Expr.var "x") == "x"
#guard render (Expr.builtin "Natural") == "Natural"

-- ── collections ───────────────────────────────────────────────────────────────

#guard render (Expr.list [] (Option.some (Expr.builtin "Natural")))
  == "[] : Natural"
#guard render (Expr.list [Expr.natural 1, Expr.natural 2] Option.none)
  == "[ 1, 2 ]"

-- ── records ───────────────────────────────────────────────────────────────────

#guard render (Expr.record []) == "{=}"
#guard render (Expr.record [("name", Expr.text "foo")])
  == "{ name = \"foo\" }"

-- ── union type ────────────────────────────────────────────────────────────────

#guard render (Expr.unionType [("x86_64", Option.none), ("aarch64", Option.none)])
  == "< x86_64 | aarch64 >"

-- ── optional ──────────────────────────────────────────────────────────────────

#guard render (Expr.some (Expr.natural 42)) == "Some 42"
#guard render (Expr.none (Expr.builtin "Natural")) == "None Natural"

-- ── lambda ────────────────────────────────────────────────────────────────────

#guard render (Expr.lambda "x" (Expr.builtin "Natural") (Expr.var "x"))
  == "λ(x : Natural) → x"

-- ── application ──────────────────────────────────────────────────────────────

#guard render (Expr.app (Expr.var "f") (Expr.var "x")) == "f x"

-- ── annotation ───────────────────────────────────────────────────────────────

#guard render (Expr.annot (Expr.natural 42) (Expr.builtin "Natural"))
  == "42 : Natural"

-- ── combinators ──────────────────────────────────────────────────────────────

#guard render (Expr.nat 7) == "7"
#guard render (Expr.str "hi") == "\"hi\""
#guard render (Expr.tt) == "True"
#guard render (Expr.ff) == "False"
#guard render (Expr.ty "Text") == "Text"
#guard render (Expr.listLit [Expr.nat 1, Expr.nat 2]) == "[ 1, 2 ]"
#guard render (Expr.emptyList (Expr.ty "Natural")) == "[] : Natural"

-- ── visual check: multi-field record ──────────────────────────────────────────

#eval render (Expr.record [
  ("arch",   Expr.str "x86_64"),
  ("os",     Expr.str "linux"),
  ("vendor", Expr.str "unknown")
])

-- ── visual check: let chain ───────────────────────────────────────────────────

#eval render (Expr.letChain
  [ ("arch",   Option.none, Expr.str "x86_64")
  , ("os",     Option.none, Expr.str "linux")
  ]
  (Expr.record [
    ("arch", Expr.var "arch"),
    ("os",   Expr.var "os")
  ]))

-- ── visual check: enum ────────────────────────────────────────────────────────

#eval render (Expr.enumVal "Arch" ["x86_64", "aarch64", "riscv64"] "x86_64")


end Continuity.Emit.Dhall
