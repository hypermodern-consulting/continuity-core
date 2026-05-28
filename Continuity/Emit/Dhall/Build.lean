import Continuity.Emit.Dhall.Ast
import Continuity.Emit.Dhall.Render

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                   // continuity // emit // dhall
                                                                     build.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Builder DSL — monadic helpers for ergonomic AST construction.

  The raw AST constructors are precise but verbose. This module provides
  three builder monads (record, let-chain, list) that let codegen authors
  write in a `do` block that reads close to the output.

  These are the ONLY way codegen functions should build AST values.
  If you're writing `Expr.record [("name", ...)]` by hand, use a builder.
-/

namespace Continuity.Emit.Dhall


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // record builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates record fields. Use with `buildRecord do ...` -/
abbrev RecordM := StateM (List (String × Expr))

/-- Add a field to the record being built -/
def field (name : String) (value : Expr) : RecordM Unit :=
  modify fun fields => fields ++ [(name, value)]

/-- Add a field only when a value is present.
    renders as `Some value` when present, `None ty` when absent -/
def optField {α : Type} (name : String) (ty : Expr) (value : Option α) (f : α → Expr) : RecordM Unit :=
  match value with
  | Option.some v => field name (Expr.some (f v))
  | Option.none   => field name (Expr.none ty)

/-- Add a field only when a condition holds. omits the field entirely if false -/
def whenField (cond : Bool) (name : String) (value : Expr) : RecordM Unit :=
  if cond then field name value else pure ()

/-- Add a list of fields from another source -/
def fields (fs : List (String × Expr)) : RecordM Unit :=
  modify fun existing => existing ++ fs

/-- Run a record builder, producing a record expression -/
def buildRecord (m : RecordM Unit) : Expr :=
  let (_, fs) := m.run []
  Expr.record fs

/-- Run a record builder, producing a record type expression -/
def buildRecordType (m : RecordM Unit) : Expr :=
  let (_, fs) := m.run []
  Expr.recordType fs


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // let-chain builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates let bindings. Use with `buildLets (body) do ...` -/
abbrev LetM := StateM (List (String × Option Expr × Expr))

/-- Add an untyped let binding: `let name = value` -/
def letBind (name : String) (value : Expr) : LetM Unit :=
  modify fun bindings => bindings ++ [(name, Option.none, value)]

/-- Add a typed let binding: `let name : ty = value` -/
def letTyped (name : String) (ty : Expr) (value : Expr) : LetM Unit :=
  modify fun bindings => bindings ++ [(name, Option.some ty, value)]

/-- Run a let-chain builder, wrapping the body in accumulated bindings -/
def buildLets (body : Expr) (m : LetM Unit) : Expr :=
  let (_, bindings) := m.run []
  Expr.letChain bindings body


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // list builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Accumulates list elements. Use with `buildList do ...` -/
abbrev ListM := StateM (List Expr)

/-- Add an element to the list being built -/
def item (value : Expr) : ListM Unit :=
  modify fun items => items ++ [value]

/-- Add an element only when a condition holds -/
def whenItem (cond : Bool) (value : Expr) : ListM Unit :=
  if cond then item value else pure ()

/-- Add all elements from a list, mapping each through a function -/
def items {α : Type} (xs : List α) (f : α → Expr) : ListM Unit :=
  modify fun existing => existing ++ xs.map f

/-- Run a list builder, producing a list expression.
    n.b. if the result is empty you must provide a type annotation
    separately, or use `buildTypedList` -/
def buildList (m : ListM Unit) : Expr :=
  let (_, elems) := m.run []
  Expr.list elems Option.none

/-- Run a list builder with a type for the empty case -/
def buildTypedList (elemType : Expr) (m : ListM Unit) : Expr :=
  let (_, elems) := m.run []
  if elems.isEmpty
  then Expr.list [] (Option.some elemType)
  else Expr.list elems Option.none


/- ════════════════════════════════════════════════════════════════════════════════
                                                             // module builder
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Build a complete Dhall module with a header and let-chain body -/
def buildModule (header : String) (body : Expr) : Module :=
  { header := Option.some header
  , body := body }


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

open Expr in
#eval render (buildRecord do
  field "arch"   (str "x86_64")
  field "os"     (str "linux")
  field "vendor" (str "unknown"))

open Expr in
#eval render (buildLets
  (buildRecord do
    field "host"      (Expr.var "host")
    field "toolchain" (Expr.var "toolchain"))
  do
    letBind "host" (str "x86_64-unknown-linux-gnu")
    letBind "toolchain" (str "nix-cxx"))

open Expr in
#eval render (buildTypedList (Expr.ty "Text") do
  item (str "foo.cpp")
  item (str "bar.cpp")
  item (str "baz.cpp"))

-- empty list with type
open Expr in
#guard render (buildTypedList (Expr.ty "Text") (pure ())) == "[] : Text"

-- single-field record
open Expr in
#guard render (buildRecord do field "name" (str "hello"))
  == "{ name = \"hello\" }"

-- conditional field: present
open Expr in
#eval render (buildRecord do
  field "name" (str "mylib")
  whenField true "debug" (Expr.bool true)
  whenField false "unused" (Expr.bool false))

-- optional field
open Expr in
#eval render (buildRecord do
  field "name" (str "mylib")
  optField "gpu" (Expr.ty "Text") (Option.some "sm_90a") Expr.str
  optField "cpu" (Expr.ty "Text") (Option.none) Expr.str)


end Continuity.Emit.Dhall
