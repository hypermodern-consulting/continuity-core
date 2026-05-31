import Continuity.Build.BzlFile

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                           // continuity // emit // starlark
                                                                  render.lean

   "Wintermute was a simple brute force, a vast shotgun."
                                                               — Neuromancer
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Starlark renderer — the ONLY place .bzl / BUCK text is assembled.

  One entry point: `renderBzlFile`. Everything else is a helper.
  Generated files should be parseable by `buildifier` without changes.
-/

set_option autoImplicit false

namespace Continuity.Emit.Starlark

open Continuity.Build


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

private def renderStrLit (s : String) : String := s!"\"{escapeStr s}\""

/-- Render a list of strings as a Starlark list literal. -/
private def renderStrList (items : List String) : String :=
  if items.isEmpty then "[]"
  else
    let inner := String.intercalate ", " (items.map renderStrLit)
    s!"[{inner}]"

/-- Render a list of strings as a multi-line Starlark list literal. -/
private def renderStrListMulti (indent : Nat) (items : List String) : String :=
  if items.isEmpty then "[]"
  else if items.length ≤ 3 then renderStrList items
  else
    let lines := items.map fun s => s!"{pad (indent + 4)}{renderStrLit s},"
    s!"[\n{String.intercalate "\n" lines}\n{pad indent}]"


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // load statements
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderLoad (l : Load) : String :=
  let syms := String.intercalate ", " (l.symbols.map renderStrLit)
  s!"load({renderStrLit l.bzl}, {syms})"


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // providers
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderProviderField : ProviderField → String
  | .typed name type dflt =>
    let dfltStr := match dflt with
      | some d => s!", default = {renderStrLit d}"
      | none   => ""
    s!"\"{name}\": provider_field({renderStrLit type}{dfltStr})"
  | .simple name => renderStrLit name

private def renderProvider (p : ProviderDef) : String :=
  let fields := String.intercalate ", " (p.fields.map renderProviderField)
  s!"{p.name} = provider(fields = [{fields}])"


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // attr types
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderAttrType : AttrType → String
  | .string (some d)   => s!"attrs.string(default = {renderStrLit d})"
  | .string none       => "attrs.string()"
  | .stringList        => "attrs.list(attrs.string(), default = [])"
  | .bool d            => s!"attrs.bool(default = {if d then "True" else "False"})"
  | .int d             => s!"attrs.int(default = {d})"
  | .dep               => "attrs.dep()"
  | .depDefault d      => s!"attrs.dep(default = {renderStrLit d})"
  | .depList           => "attrs.list(attrs.dep(), default = [])"
  | .execDep (some d)  => s!"attrs.exec_dep(default = {renderStrLit d})"
  | .execDep none      => "attrs.exec_dep()"
  | .source            => "attrs.source()"
  | .sourceList        => "attrs.list(attrs.source(), default = [])"
  | .optionSource      => "attrs.option(attrs.source(), default = None)"
  | .optionString      => "attrs.option(attrs.string(), default = None)"
  | .optionExecDep providers dflt =>
    let plist := String.intercalate ", " providers
    let dfltStr := match dflt with
      | some d => s!", default = {renderStrLit d}"
      | none   => ", default = None"
    s!"attrs.option(attrs.exec_dep(providers = [{plist}]){dfltStr})"
  | .output            => "attrs.output()"
  | .label             => "attrs.label()"
  | .stringDict        => "attrs.dict(key = attrs.string(), value = attrs.string(), default = {})"

private def renderAttr (a : Attr) : String :=
  s!"\"{a.name}\": {renderAttrType a.type}"


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // helper functions
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderHelperFn (h : HelperFn) : String :=
  let retAnnotation := match h.returnType with
    | some t => s!" -> {t}"
    | none   => ""
  let params := String.intercalate ", " h.params
  s!"def {h.name}({params}){retAnnotation}:\n{h.body}"


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // rules
   ════════════════════════════════════════════════════════════════════════════════ -/

private def renderRule (r : BzlRule) : String :=
  let implFn := s!"def {r.impl.name}(ctx: AnalysisContext) -> list[Provider]:\n{r.impl.body}"
  let attrLines := r.attrs.map fun a => s!"        {renderAttr a},"
  let attrBlock := String.intercalate "\n" attrLines
  let implKw := if r.impl.is_toolchain then "True" else "False"
  -- The public rule name: strip leading underscore and _impl suffix
  let pubName := r.impl.name.stripPrefix "_" |>.stripSuffix "_impl"
  let doc := if r.impl.doc.isEmpty then "" else s!"\n    doc = \"\"\"{r.impl.doc}\"\"\","
  s!"{implFn}\n\n{pubName} = rule(\n    impl = {r.impl.name},{doc}\n    is_toolchain_rule = {implKw},\n    attrs = \{\n{attrBlock}\n    },\n)"


/- ════════════════════════════════════════════════════════════════════════════════
                                                         // top-level render
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Render a complete BzlFile to Starlark text. -/
def renderBzlFile (f : BzlFile) : String :=
  let sections : List String := List.filter (· ≠ "") [
    -- header comment
    (if f.header.isEmpty then "" else f.header),
    -- load statements
    (if f.loads.isEmpty then ""
     else String.intercalate "\n" (f.loads.map renderLoad)),
    -- globals
    f.globals,
    -- providers
    (if f.providers.isEmpty then ""
     else String.intercalate "\n" (f.providers.map renderProvider)),
    -- helpers
    (if f.helpers.isEmpty then ""
     else String.intercalate "\n\n" (f.helpers.map renderHelperFn)),
    -- rules
    (if f.rules.isEmpty then ""
     else String.intercalate "\n\n\n" (f.rules.map renderRule))
  ]
  String.intercalate "\n\n" sections ++ "\n"


/- ════════════════════════════════════════════════════════════════════════════════
                                                        // BUCK file render
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A toolchain instantiation in a BUCK file. -/
structure ToolchainCall where
  ruleFunc   : String          -- e.g. "system_cxx_toolchain"
  name       : String          -- e.g. "cxx"
  kwargs     : List (String × String)  -- key-value pairs (already rendered)
  visibility : List String := ["PUBLIC"]
  deriving Repr, Inhabited

/-- Render a single toolchain call in a BUCK file. -/
def renderToolchainCall (t : ToolchainCall) : String :=
  let vis := renderStrList t.visibility
  let kwargLines := t.kwargs.map fun (k, v) => s!"    {k} = {v},"
  let allLines := [s!"    name = {renderStrLit t.name},"]
    ++ kwargLines
    ++ [s!"    visibility = {vis},"]
  s!"{t.ruleFunc}(\n{String.intercalate "\n" allLines}\n)"

/-- A complete BUCK file for toolchains. -/
structure BuckFile where
  header  : String := ""
  loads   : List Load := []
  calls   : List ToolchainCall := []
  deriving Repr, Inhabited

/-- Render a toolchains/BUCK file. -/
def renderBuckFile (b : BuckFile) : String :=
  let sections : List String := List.filter (· ≠ "") [
    b.header,
    (if b.loads.isEmpty then ""
     else String.intercalate "\n" (b.loads.map renderLoad)),
    (if b.calls.isEmpty then ""
     else String.intercalate "\n\n" (b.calls.map renderToolchainCall))
  ]
  String.intercalate "\n\n" sections ++ "\n"


end Continuity.Emit.Starlark
