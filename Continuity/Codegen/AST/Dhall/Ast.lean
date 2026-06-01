/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The box was a universe, a poem, frozen on the boundaries
      of human experience. He had built it, or found it, or
      perhaps it had always been there, a latent structure
      waiting to be expressed. The thing about a box, he thought,
      was that it defined an inside and an outside, a grammar
      of containment that could be read as either enclosure or
      release, depending on where you stood and how you chose
      to parse its boundaries. Every configuration implied a
      truth about the world that built it."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Dhall

/-
  `Dhall` AST — near-complete abstract syntax for the `Dhall` configuration language.

  This covers the full expression grammar minus: Date/Time/TimeZone literals,
  Bytes literals, Double literals, URL imports, import alternatives (`?`),
  `showConstructor`, and de Bruijn indices on variables (we generate unique
  names). Everything else you can write in `Dhall`, you can emit from here.

  cf. https://github.com/dhall-lang/dhall-lang/blob/master/standard/README.md
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // binary // operators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `Dhall` binary operators, in precedence order (low to high)
inductive BinOp where
  -- `a === b` — equivalence (for assert)
  | equiv
  -- `a // b` — right-biased record merge (⫽)
  | prefer
  -- `a //\\ b` — recursive record type merge (⩓)
  | combine
  -- `a /\ b` — recursive record merge (∧)
  | combineTypes
  -- `a # b` — list append
  | listAppend
  -- `a ++ b` — text append
  | textAppend
  -- `a || b` — boolean or
  | boolOr
  -- `a && b` — boolean and
  | boolAnd
  -- `a == b` — boolean equality
  | boolEq
  -- `a != b` — boolean inequality
  | boolNe
  -- `a + b` — natural addition
  | natPlus
  -- `a * b` — natural multiplication
  | natTimes
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // imports
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- how to interpret an import's content
inductive ImportMode where
  -- default: parse as `Dhall` expression
  | code
  -- `as Text`: import as raw `Text`
  | asText
  -- `as Bytes`: import as raw `Bytes`
  | asBytes
  -- `as Location`: import as a `Location` value
  | asLocation
  deriving Repr, DecidableEq, Inhabited

-- an import reference
inductive Import where
  -- local file: `./path/to/file.dhall`
  | file (path : String)
  -- parent traversal: `../path/to/file.dhall`
  | parentFile (path : String)
  -- absolute: `/path/to/file.dhall`
  | absFile (path : String)
  -- home-anchored: `~/path/to/file.dhall`
  | homeFile (path : String)
  -- environment variable: `env:VAR`
  | env (name : String)
  -- `missing` — always fails, used as import alternative fallback
  | missing
  deriving Repr, DecidableEq, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // expressions
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a `Dhall` expression. covers the full surface syntax minus the
-- omissions listed in the module doc.
inductive Expr where

  -- literals

  -- `True` or `False`
  | bool (value : Bool)
  -- `42`
  | natural (value : Nat)
  -- `+3` or `-7`
  | integer (value : Int)
  -- `"hello"` — double-quoted text
  | text (value : String)
  -- `"prefix ${expr} suffix"` — text with interpolations.
  -- texts and exprs alternate: texts[0] exprs[0] texts[1] exprs[1] ... texts[n]
  | interpolation (texts : List String) (exprs : List Expr)
  -- `'' multi-line ${expr} text ''` — multi-line text with interpolations.
  -- same alternating structure as interpolation. leading whitespace is
  -- stripped per `Dhall` spec, but we emit verbatim — the caller handles
  -- indentation
  | textBlock (texts : List String) (exprs : List Expr)

  -- references

  -- variable reference: `x`
  | var (name : String)
  -- import: `./file.dhall`, `env:VAR`, `missing`
  | import_ (ref : Import) (mode : ImportMode) (integrity : Option String)

  -- collections

  -- `[1, 2, 3]` or `[] : List Natural`
  | list (elements : List Expr) (emptyType : Option Expr)
  -- `{ name = "foo", version = 1 }`
  | record (fields : List (String × Expr))
  -- `{ name : Text, version : Natural }`
  | recordType (fields : List (String × Expr))
  -- `r.name` — field access
  | field (expr : Expr) (name : String)
  -- `r.{ name, version }` — record projection by field names
  | project (expr : Expr) (fieldNames : List String)
  -- `r.(T)` — record projection by type
  | projectType (expr : Expr) (ty : Expr)

  -- unions

  -- `< x86_64 | aarch64 | riscv64 >`
  | unionType (alternatives : List (String × Option Expr))
  -- union constructor applied: `< Arch >.x86_64`
  | unionVal (typeName : String) (alternatives : List (String × Option Expr))
             (tag : String) (value : Option Expr)

  -- functions

  -- `λ(x : Natural) → x + 1`
  | lambda (param : String) (paramType : Expr) (body : Expr)
  -- `∀(x : Natural) → x < 10` — pi / forall type
  | forallE (param : String) (paramType : Expr) (body : Expr)
  -- `f x` — function application
  | app (fn : Expr) (arg : Expr)

  -- binding

  -- `let x : T = e in body` — type annotation optional
  | letIn (name : String) (ty : Option Expr) (value : Expr) (body : Expr)
  -- `if c then t else f`
  | ite (cond : Expr) (thenBranch : Expr) (elseBranch : Expr)

  -- operators

  -- binary operator application: `a op b`
  | binop (op : BinOp) (lhs : Expr) (rhs : Expr)
  -- `T::r` — completion (fill defaults from type)
  | completion (ty : Expr) (value : Expr)
  -- `r with a.b.c = x` — deep record update
  | with (expr : Expr) (path : List String) (value : Expr)

  -- type annotation

  -- `expr : Type`
  | annot (expr : Expr) (ty : Expr)

  -- optional

  -- `Some 42`
  | some (value : Expr)
  -- `None Natural`
  | none (ty : Expr)

  -- builtins

  -- built-in name: `Natural`, `Text`, `Bool`, `List`, `Optional`,
  --   `Type`, `Kind`, `Natural/fold`, `List/map`, etc.
  | builtin (name : String)

  -- special forms

  -- `merge { Left = f, Right = g } union : T`
  | merge (handler : Expr) (union : Expr) (ty : Option Expr)
  -- `toMap { x = 1, y = 2 } : List { mapKey : Text, mapValue : Natural }`
  | toMap (expr : Expr) (ty : Option Expr)
  -- `assert : x === y`
  | assert (annot : Expr)

  -- metadata

  -- `{- comment -}` attached above an expression
  | comment (text : String) (body : Expr)

  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                 // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- thin helpers. every one is a one-liner.

namespace Expr

-- literal shortcuts

def nat (n : Nat) : Expr := Expr.natural n
def str (s : String) : Expr := Expr.text s
def tt : Expr := Expr.bool true
def ff : Expr := Expr.bool false

-- type shortcuts

def ty (name : String) : Expr := Expr.builtin name

def listOf (elemType : Expr) : Expr :=
  Expr.app (Expr.builtin "List") elemType

def optionalOf (elemType : Expr) : Expr :=
  Expr.app (Expr.builtin "Optional") elemType

-- collection shortcuts

def listLit (elements : List Expr) : Expr :=
  Expr.list elements Option.none

def emptyList (elemType : Expr) : Expr :=
  Expr.list [] (Option.some (Expr.app (Expr.builtin "List") elemType))

-- binding shortcuts

def letChain (bindings : List (String × Option Expr × Expr)) (body : Expr) : Expr :=
  bindings.foldr (fun (name, ty, value) acc => Expr.letIn name ty value acc) body

def apps (fn : Expr) (args : List Expr) : Expr :=
  args.foldl (fun acc arg => Expr.app acc arg) fn

-- union shortcuts

def enum (alternatives : List String) : Expr :=
  Expr.unionType (alternatives.map fun a => (a, Option.none))

def enumVal (typeName : String) (alternatives : List String) (tag : String) : Expr :=
  Expr.unionVal typeName
    (alternatives.map fun a => (a, Option.none))
    tag
    Option.none

-- operator shortcuts

def recordMerge (lhs : Expr) (rhs : Expr) : Expr :=
  Expr.binop BinOp.prefer lhs rhs

def listConcat (lhs : Expr) (rhs : Expr) : Expr :=
  Expr.binop BinOp.listAppend lhs rhs

def textConcat (lhs : Expr) (rhs : Expr) : Expr :=
  Expr.binop BinOp.textAppend lhs rhs

-- import shortcuts

def importFile (path : String) : Expr :=
  Expr.import_ (Import.file path) ImportMode.code Option.none

def importParentFile (path : String) : Expr :=
  Expr.import_ (Import.parentFile path) ImportMode.code Option.none

def importFileAsText (path : String) : Expr :=
  Expr.import_ (Import.file path) ImportMode.asText Option.none

def importEnv (name : String) : Expr :=
  Expr.import_ (Import.env name) ImportMode.code Option.none

-- non-dependent function type

-- `A → B` — non-dependent function type. rendered as `∀(_ : A) → B`
def arrow (domain : Expr) (codomain : Expr) : Expr :=
  Expr.forallE "_" domain codomain

end Expr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // top-level // module
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a complete `Dhall` file.
structure Module where
  -- file-level comment block, rendered before the expression
  header : Option String := Option.none
  -- the expression that constitutes the file's content
  body : Expr
  deriving Repr, Inhabited

end Continuity.Codegen.AST.Dhall
