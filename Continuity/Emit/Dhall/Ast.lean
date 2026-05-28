/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // emit // dhall
                                                                       ast.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Dhall AST — abstract syntax for the Dhall configuration language.

  This is NOT a codec target. Dhall is the render target for build descriptions:
  triples, toolchains, rules, derivations. The structures in Build/ are the
  source of truth; this AST is the shape of the output.

  We model a minimal subset of Dhall — just enough to emit readable build
  configurations. No imports, no type inference, no normalization. If Dhall
  has it and we don't emit it, it's not here.

  cf. https://github.com/dhall-lang/dhall-lang/blob/master/standard/README.md
-/

namespace Continuity.Emit.Dhall


/- ════════════════════════════════════════════════════════════════════════════════
                                                                  // expressions
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A Dhall expression.

    This is the single AST type. Dhall is expression-oriented — there are no
    statements. A Dhall file is one expression, usually a record or a let chain
    that bottoms out in a record. -/
inductive Expr where
  /-- boolean literal: `True` or `False` -/
  | bool (value : Bool)

  /-- natural number literal: `42` -/
  | natural (value : Nat)

  /-- integer literal: `+3` or `-7`.
      n.b. dhall integers are always signed and always prefixed -/
  | integer (value : Int)

  /-- double-quoted text: `"hello world"` -/
  | text (value : String)

  /-- text with interpolations: `"prefix ${expr} suffix"`.
      segments alternate: text, expr, text, expr, ..., text.
      the text list is always one longer than the expr list -/
  | interpolation (texts : List String) (exprs : List Expr)

  /-- variable reference: `x` -/
  | var (name : String)

  /-- list literal: `[1, 2, 3]`.
      for empty lists, provide a type: `[] : List Natural` -/
  | list (elements : List Expr) (emptyType : Option Expr)

  /-- record literal: `{ arch = "x86_64", os = "linux" }`.
      fields are name-expression pairs. order is preserved as written -/
  | record (fields : List (String × Expr))

  /-- record type: `{ arch : Text, os : Text }` -/
  | recordType (fields : List (String × Expr))

  /-- field access: `r.arch` -/
  | field (expr : Expr) (name : String)

  /-- union type: `< x86_64 | aarch64 | riscv64 >` -/
  | unionType (alternatives : List (String × Option Expr))

  /-- union value: `< Arch >.x86_64` or with payload -/
  | unionVal (typeName : String) (alternatives : List (String × Option Expr))
             (tag : String) (value : Option Expr)

  /-- lambda: `λ(x : Natural) → x + 1` -/
  | lambda (param : String) (paramType : Expr) (body : Expr)

  /-- function application: `f x` -/
  | app (fn : Expr) (arg : Expr)

  /-- let binding: `let x : T = e in body`.
      type annotation is optional -/
  | letIn (name : String) (ty : Option Expr) (value : Expr) (body : Expr)

  /-- type annotation: `expr : Type` -/
  | annot (expr : Expr) (ty : Expr)

  /-- optional present: `Some 42` -/
  | some (value : Expr)

  /-- optional absent: `None Natural` -/
  | none (ty : Expr)

  /-- built-in type name: `Natural`, `Text`, `Bool`, `List`, `Optional` -/
  | builtin (name : String)

  /-- merge expression: `merge { Left = ..., Right = ... } union` -/
  | merge (handler : Expr) (union : Expr) (ty : Option Expr)

  /-- raw comment attached to an expression, rendered above it -/
  | comment (text : String) (body : Expr)

  deriving Repr, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                                 // combinators
   ════════════════════════════════════════════════════════════════════════════════ -/

/-! thin helpers for building AST values. these exist to keep call sites
    readable — every one is a one-liner that saves keystrokes and
    makes intent clearer.

    n.b. we define these outside the inductive because lean needs
    the type to be fully elaborated before we can write functions on it. -/

namespace Expr

-- ── literals ──────────────────────────────────────────────────────────────────

def nat (n : Nat) : Expr := Expr.natural n
def str (s : String) : Expr := Expr.text s
def tt : Expr := Expr.bool true
def ff : Expr := Expr.bool false

-- ── types ─────────────────────────────────────────────────────────────────────

def ty (name : String) : Expr := Expr.builtin name

def listOf (elemType : Expr) : Expr :=
  Expr.app (Expr.builtin "List") elemType

def optionalOf (elemType : Expr) : Expr :=
  Expr.app (Expr.builtin "Optional") elemType

-- ── collections ───────────────────────────────────────────────────────────────

/-- non-empty list (no type annotation needed) -/
def listLit (elements : List Expr) : Expr :=
  Expr.list elements Option.none

/-- empty list with type: `[] : List Natural` -/
def emptyList (elemType : Expr) : Expr :=
  Expr.list [] (Option.some elemType)

-- ── binding ───────────────────────────────────────────────────────────────────

/-- chain of let bindings: `let a = ... in let b = ... in body` -/
def letChain (bindings : List (String × Option Expr × Expr)) (body : Expr) : Expr :=
  bindings.foldr (fun (name, ty, value) acc => Expr.letIn name ty value acc) body

/-- apply a function to multiple arguments left-to-right -/
def apps (fn : Expr) (args : List Expr) : Expr :=
  args.foldl (fun acc arg => Expr.app acc arg) fn

-- ── union shorthand ───────────────────────────────────────────────────────────

/-- simple enum union: `< A | B | C >` (no payloads) -/
def enum (alternatives : List String) : Expr :=
  Expr.unionType (alternatives.map fun a => (a, Option.none))

/-- simple enum value: `< A | B | C >.B` -/
def enumVal (typeName : String) (alternatives : List String) (tag : String) : Expr :=
  Expr.unionVal typeName
    (alternatives.map fun a => (a, Option.none))
    tag
    Option.none

end Expr


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // top-level module
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A complete Dhall file.

    In practice a generated Dhall file is a single expression, usually a let
    chain. This structure gives us a place to hang the file-level comment
    header without stuffing it into the expression tree. -/
structure Module where
  /-- file-level comment block, rendered before the expression -/
  header : Option String := Option.none
  /-- the expression that constitutes the file's content -/
  body : Expr
  deriving Repr, Inhabited


end Continuity.Emit.Dhall
