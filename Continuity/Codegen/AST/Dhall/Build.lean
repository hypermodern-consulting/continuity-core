import Continuity.Codegen.AST.Dhall.Ast
import Continuity.Codegen.AST.Dhall.Render

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The mindless glide of the thing," he'd said, watching the constructor
      arms sweep across the assembly bed, the same six welds in the same
      sequence, over and over. Turner had watched too, but what he'd seen
      was the template: the platonic mold from which the motion fell.
      Everything that happened on that line was just the shadow of a
      record field, cast into steel. The real building had happened
      already, somewhere else, in a language that spoke only in
      let-bindings and type unions, assembling the blueprint by monadic
      accumulation. By the time the arms moved, the work was done.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Dhall

/-
  builder DSL — monadic helpers for ergonomic AST construction.

  The raw AST constructors are precise but verbose. This module provides
  three builder monads (record, let-chain, list) that let codegen authors
  write in a `do` block that reads close to the output.

  These are the ONLY way codegen functions should build AST values.
  If you're writing `Expr.record [("name", ...)]` by hand, use a builder.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // record builder
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- accumulates record fields. use with `buildRecord` do ...
abbrev RecordM := StateM (List (String × Expr))

-- add a field to the record being built
def field (name : String) (value : Expr) : RecordM Unit :=
  modify fun fields => fields ++ [(name, value)]

-- add a field only when a value is present.
-- renders as `Some value` when present, `None ty` when absent
def optField {α : Type} (name : String) (ty : Expr) (value : Option α) (f : α → Expr) : RecordM Unit :=
  match value with
  | Option.some v => field name (Expr.some (f v))
  | Option.none   => field name (Expr.none ty)

-- add a field only when a condition holds. omits the field entirely if false
def whenField (cond : Bool) (name : String) (value : Expr) : RecordM Unit :=
  if cond then field name value else pure ()

-- add a list of fields from another source
def fields (fs : List (String × Expr)) : RecordM Unit :=
  modify fun existing => existing ++ fs

-- run a record builder, producing a record expression
def buildRecord (m : RecordM Unit) : Expr :=
  let (_, fs) := m.run []
  Expr.record fs

-- run a record builder, producing a record type expression
def buildRecordType (m : RecordM Unit) : Expr :=
  let (_, fs) := m.run []
  Expr.recordType fs

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // let-chain // builder
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- accumulates let bindings. use with `buildLets body` do ...
abbrev LetM := StateM (List (String × Option Expr × Expr))

-- add an untyped let binding: `let name = value`
def letBind (name : String) (value : Expr) : LetM Unit :=
  modify fun bindings => bindings ++ [(name, Option.none, value)]

-- add a typed let binding: `let name : ty = value`
def letTyped (name : String) (ty : Expr) (value : Expr) : LetM Unit :=
  modify fun bindings => bindings ++ [(name, Option.some ty, value)]

-- run a let-chain builder, wrapping the body in accumulated bindings
def buildLets (body : Expr) (m : LetM Unit) : Expr :=
  let (_, bindings) := m.run []
  Expr.letChain bindings body

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // list // builder
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- accumulates list elements. use with `buildList` do ...
abbrev ListM := StateM (List Expr)

-- add an element to the list being built
def item (value : Expr) : ListM Unit :=
  modify fun items => items ++ [value]

-- add an element only when a condition holds
def whenItem (cond : Bool) (value : Expr) : ListM Unit :=
  if cond then item value else pure ()

-- add all elements from a list, mapping each through a function
def items {α : Type} (xs : List α) (f : α → Expr) : ListM Unit :=
  modify fun existing => existing ++ xs.map f

-- run a list builder, producing a list expression.
-- n.b. if the result is empty you must provide a type annotation
-- separately, or use `buildTypedList`
def buildList (m : ListM Unit) : Expr :=
  let (_, elems) := m.run []
  Expr.list elems Option.none

-- run a list builder with a type for the empty case
def buildTypedList (elemType : Expr) (m : ListM Unit) : Expr :=
  let (_, elems) := m.run []
  if elems.isEmpty
  then Expr.list [] (Option.some elemType)
  else Expr.list elems Option.none

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // module // builder
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- build a complete `Dhall` module with a header and let-chain body
def buildModule (header : String) (body : Expr) : Module :=
  { header := Option.some header
  , body := body }

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                       // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- empty list with type
open Expr in
#guard render (buildTypedList (Expr.ty "Text") (pure ())) == "[] : Text"

-- single-field record
open Expr in
#guard render (buildRecord do field "name" (str "hello"))
  == "{ name = \"hello\" }"

-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

-- conditional field: present
-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!
-- optional field
-- TODO[b7r6]: !! decide what to do with all of these `#eval` stanzas !!

end Continuity.Codegen.AST.Dhall
