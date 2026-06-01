set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Bobby Newmark, aka Count Zero, but it was already
      over — the name, the identity, the carefully
      constructed facade of rules that determine who you
      are and what you are permitted to build. Rules are
      not constraints, the Finn had told him once. Rules
      are the grammar of making. Without them, you do not
      have a language. You have noise. Every artifact
      worth its provenance was built inside a cage of
      formal expectations, and the art lay in knowing
      which bars to bend and which to leave in place."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Build

/-
  `BzlFile` — `Buck2` rule definition types.

  These describe the *shape* of a `.bzl` rule file: what attrs it has,
  what providers it declares, what its implementation body is. The
  actual rendering to `Starlark` text is done in `Dhall` (`to-starlark.dhall`).

  Types + terms in one file. The terms here are validation and
  structural constraint functions, not `Starlark` emission.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // attr types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive AttrType where
  | string (dflt : Option String)
  | stringList
  | bool (dflt : Bool)
  | int (dflt : Nat)
  | dep
  | depDefault (dflt : String)
  | depList
  | execDep (dflt : Option String)
  | source
  | sourceList
  | optionSource
  | optionString
  | optionExecDep (providers : List String) (dflt : Option String)
  | output
  | label
  | stringDict
  | raw (text : String)  -- pre-rendered attr type, for edge cases
  deriving Repr, Inhabited

structure Attr where
  name : String
  type : AttrType
  doc  : String := ""
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // provider types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive ProviderField where
  | typed (name : String) (type : String) (dflt : Option String)
  | simple (name : String)
  deriving Repr, Inhabited

structure ProviderDef where
  name   : String
  fields : List ProviderField
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // rule + file types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure Load where
  bzl     : String
  symbols : List String
  deriving Repr, Inhabited

structure HelperFn where
  name       : String
  params     : List String
  returnType : Option String := Option.none
  body       : String
  deriving Repr, Inhabited

structure RuleImpl where
  name         : String
  doc          : String := ""
  body         : String    -- raw `Starlark` implementation
  is_toolchain : Bool := false
  deriving Repr, Inhabited

structure BzlRule where
  impl  : RuleImpl
  attrs : List Attr
  deriving Repr, Inhabited

structure BzlFile where
  header    : String := ""
  loads     : List Load := []
  globals   : String := ""
  providers : List ProviderDef := []
  helpers   : List HelperFn := []
  rules     : List BzlRule := []
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // constructors
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def Attr.string_ (name : String) (dflt : Option String := Option.none) : Attr :=
  ⟨name, AttrType.string dflt, ""⟩
def Attr.stringList_ (name : String) : Attr := ⟨name, AttrType.stringList, ""⟩
def Attr.bool_ (name : String) (dflt : Bool) : Attr := ⟨name, AttrType.bool dflt, ""⟩
def Attr.source_ (name : String) : Attr := ⟨name, AttrType.source, ""⟩
def Attr.sourceList_ (name : String) : Attr := ⟨name, AttrType.sourceList, ""⟩
def Attr.dep_ (name : String) : Attr := ⟨name, AttrType.dep, ""⟩
def Attr.depList_ (name : String) : Attr := ⟨name, AttrType.depList, ""⟩

end Continuity.Build
