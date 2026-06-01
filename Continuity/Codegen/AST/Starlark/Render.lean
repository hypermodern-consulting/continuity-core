import Continuity.Build.BzlFile
import Continuity.Codegen.AST.Starlark.Ast

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Shee-it, I figured it was a big one, but I guess it's gonna be a rough
      one, too." Bobby ran a thumb along the edge of the stack of printout.
      "See, the funny thing is, whoever set this up, they built it to last.
      Every piece fits. Every joint is clean. You don't get that kind of
      work unless somebody's planning to be running code through it for a
      long, long time. And they built it so the output — what comes out the
      other end — is exactly what the next stage needs. No gaps. No seams."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Starlark

/-
  Starlark renderer — the ONLY place `.bzl` / `BUCK` text is assembled.

  One entry point: `renderBzlFile`. Everything else is a helper.
  Generated files should be parseable by `buildifier` without changes.
-/

open Continuity.Build

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // helpers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

-- render a list of strings as a starlark list literal.
private def renderStrList (items : List String) : String :=
  if items.isEmpty then "[]"
  else
    let inner := String.intercalate ", " (items.map renderStrLit)
    s!"[{inner}]"

-- render a list of strings as a multi-line starlark list literal.
private def renderStrListMulti (indent : Nat) (items : List String) : String :=
  if items.isEmpty then "[]"
  else if items.length ≤ 3 then renderStrList items
  else
    let lines := items.map fun s => s!"{pad (indent + 4)}{renderStrLit s},"
    s!"[\n{String.intercalate "\n" lines}\n{pad indent}]"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // load // builders
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def renderLoad (l : Load) : String :=
  let syms := String.intercalate ", " (l.symbols.map renderStrLit)
  s!"load({renderStrLit l.bzl}, {syms})"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // providers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // attr // helpers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
  | .raw text           => text

private def renderAttr (a : Attr) : String :=
  s!"\"{a.name}\": {renderAttrType a.type}"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // helper // functions
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def renderHelperFn (h : HelperFn) : String :=
  let retAnnotation := match h.returnType with
    | some t => s!" -> {t}"
    | none   => ""
    
  let params := String.intercalate ", " h.params
  s!"def {h.name}({params}){retAnnotation}:\n{h.body}"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                       // rules
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- TODO[b7r6]: !! clean up this `renderRule` — the implFn and pubName extraction
-- is fragile. consider factoring the name munging into `BzlRule` or a helper !!

private def renderRule (r : BzlRule) : String :=
  let implFn := s!"def {r.impl.name}(ctx: AnalysisContext) -> list[Provider]:\n{r.impl.body}"
  let attrLines := r.attrs.map fun a => s!"        {renderAttr a},"
  let attrBlock := String.intercalate "\n" attrLines
  let implKw := if r.impl.is_toolchain then "True" else "False"

  -- the public rule name: strip leading underscore and `_impl` suffix
  let pubName := r.impl.name.dropPrefix "_" |>.dropPrefix "_impl"
  let doc := if r.impl.doc.isEmpty then "" else s!"\n    doc = \"\"\"{r.impl.doc}\"\"\","

  s!"{implFn}\n\n{pubName} = rule(\n    impl = {r.impl.name},{doc}\n    is_toolchain_rule = {implKw},\n    attrs = \{\n{attrBlock}\n    },\n)"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // top // level
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- render a complete `BzlFile` to starlark text.
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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                        // BUCK
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a toolchain instantiation in a `BUCK` file.
structure ToolchainCall where
  ruleFunc   : String                      -- e.g. `"system_cxx_toolchain"`
  name       : String                      -- e.g. `"cxx"`
  kwargs     : List (String × String)      -- key-value pairs (already rendered)
  visibility : List String := ["PUBLIC"]
  deriving Repr, Inhabited

-- render a single toolchain call in a `BUCK` file.
def renderToolchainCall (t : ToolchainCall) : String :=
  let vis := renderStrList t.visibility
  let kwargLines := t.kwargs.map fun (k, v) => s!"    {k} = {v},"
  
  let allLines := [s!"    name = {renderStrLit t.name},"]
    ++ kwargLines
    ++ [s!"    visibility = {vis},"]
    
  s!"{t.ruleFunc}(\n{String.intercalate "\n" allLines}\n)"

-- a complete `BUCK` file for toolchains.
structure BuckFile where
  header  : String := ""
  loads   : List Load := []
  calls   : List ToolchainCall := []
  deriving Repr, Inhabited

-- render a toolchains/BUCK file.
def renderBuckFile (b : BuckFile) : String :=
  let sections : List String := List.filter (· ≠ "") [
    b.header,
    (if b.loads.isEmpty then ""
     else String.intercalate "\n" (b.loads.map renderLoad)),
    (if b.calls.isEmpty then ""
     else String.intercalate "\n\n" (b.calls.map renderToolchainCall))
  ]
  
  String.intercalate "\n\n" sections ++ "\n"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // AST // render
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- render `SFile` to string. Builder → AST → render.

mutual

partial def renderSExpr : SExpr → String
  | .str s        => renderStrLit s
  | .strBlock s   => s!"\"\"\"{ s}\"\"\""
  | .int n        => toString n
  | .bool true    => "True"
  | .bool false   => "False"
  | .none         => "None"
  | .var name     => name
  | .dot e field  => s!"{renderSExpr e}.{field}"
  | .index e key  => s!"{renderSExpr e}[{renderSExpr key}]"
  
  | .call func args kwargs =>
    let posArgs := args.map renderSExpr
    let kwArgs  := kwargs.map fun (k, v) => s!"{k} = {renderSExpr v}"
    let allArgs := posArgs ++ kwArgs
    s!"{renderSExpr func}({String.intercalate ", " allArgs})"
    
  | .methodCall obj method args kwargs =>
    let posArgs := args.map renderSExpr
    let kwArgs  := kwargs.map fun (k, v) => s!"{k} = {renderSExpr v}"
    let allArgs := posArgs ++ kwArgs
    s!"{renderSExpr obj}.{method}({String.intercalate ", " allArgs})"
    
  | .list elements =>
    if elements.isEmpty then "[]"
    else s!"[{String.intercalate ", " (elements.map renderSExpr)}]"
    
  | .dict entries =>
    if entries.isEmpty then "{}"
    else
      let pairs := entries.map fun (k, v) => s!"{renderSExpr k}: {renderSExpr v}"
      s!"\{{String.intercalate ", " pairs}}"
      
  | .binop op lhs rhs => s!"{renderSExpr lhs} {op} {renderSExpr rhs}"
  | .unop op e        => s!"{op} {renderSExpr e}"
  | .cmp op lhs rhs   => s!"{renderSExpr lhs} {op} {renderSExpr rhs}"
  | .ternary t c e     => s!"{renderSExpr t} if {renderSExpr c} else {renderSExpr e}"
  | .concat parts      => String.intercalate " + " (parts.map renderSExpr)
  
  | .format tmpl args  =>
    let argStr := String.intercalate ", " (args.map renderSExpr)
    s!"{renderStrLit tmpl}.format({argStr})"
    
  | .raw text          => text

partial def renderSStmt (indent : Nat) : SStmt → String
  | .assign target value =>
    s!"{pad indent}{target} = {renderSExpr value}"
  | .augAssign target op value =>
    s!"{pad indent}{target} {op} {renderSExpr value}"
  | .expr value =>
    s!"{pad indent}{renderSExpr value}"
  | .ret value =>
    s!"{pad indent}return {renderSExpr value}"
    
  | .ifStmt branches elseBranch =>
    let renderBranch (isFirst : Bool) (cond : SExpr) (body : List SStmt) : String :=
      let keyword := if isFirst then "if" else "elif"
      let header := s!"{pad indent}{keyword} {renderSExpr cond}:"
      let bodyStr := String.intercalate "\n" (body.map (renderSStmt (indent + 4)))
      s!"{header}\n{bodyStr}"
      
    let branchStrs := match branches with
      | [] => []
      | (cond, body) :: rest =>
        let first := renderBranch true cond body
        let others := rest.map fun (c, b) => renderBranch false c b
        first :: others
    let elseStr := if elseBranch.isEmpty then ""
      else s!"\n{pad indent}else:\n{String.intercalate "\n" (elseBranch.map (renderSStmt (indent + 4)))}"
    String.intercalate "\n" branchStrs ++ elseStr
    
  | .forStmt var_ iterable body =>
    let header := s!"{pad indent}for {var_} in {renderSExpr iterable}:"
    let bodyStr := String.intercalate "\n" (body.map (renderSStmt (indent + 4)))
    s!"{header}\n{bodyStr}"
    
  | .comment text =>
    s!"{pad indent}# {text}"
  | .blank => ""
  | .raw text =>
    s!"{pad indent}{text}"

end

private def renderSParam (p : SParam) : String :=
  let typeStr := match p.type with
    | some t => s!": {t}"
    | none   => ""
    
  let defaultStr := match p.default with
    | some d => s!" = {renderSExpr d}"
    | none   => ""
    
  s!"{p.name}{typeStr}{defaultStr}"

private def renderSTop : STop → String
  | .load path symbols =>
    let syms := String.intercalate ", " (symbols.map renderStrLit)
    s!"load({renderStrLit path}, {syms})"
    
  | .globalAssign name value =>
    s!"{name} = {renderSExpr value}"
    
  | .provider name fields =>
    let fieldStrs := fields.map fun (fname, ftype) =>
      s!"    \"{fname}\": provider_field({ftype}),"
    s!"{name} = provider(fields = \{\n{String.intercalate "\n" fieldStrs}\n})"
    
  | .funcDef name params retType doc body =>
    let paramStr := String.intercalate ", " (params.map renderSParam)
    let retStr := match retType with
      | some t => s!" -> {t}"
      | none   => ""
      
    let docStr := match doc with
      | some d => s!"\n    \"\"\"\n    {d}\n    \"\"\""
      | none   => ""
      
    let bodyStr := String.intercalate "\n" (body.map (renderSStmt 4))
    s!"def {name}({paramStr}){retStr}:{docStr}\n{bodyStr}"
    
  | .ruleDef name implName isToolchain attrs =>
    let attrLines := attrs.map fun (aname, aexpr) =>
      s!"        \"{aname}\": {renderSExpr aexpr},"
    let attrBlock := String.intercalate "\n" attrLines
    let tcStr := if isToolchain then "\n    is_toolchain_rule = True," else ""
    s!"{name} = rule(\n    impl = {implName},{tcStr}\n    attrs = \{\n{attrBlock}\n    },\n)"
    
  | .comment text =>
    let commentLines := text.splitOn "\n"
    String.intercalate "\n" (commentLines.map fun l => s!"# {l}")
    
  | .blank => ""

-- render a complete `.bzl` file from AST.
def renderSFile (f : SFile) : String :=
  let headerStr := if f.header.isEmpty then [] else [f.header]
  let itemStrs := f.items.map renderSTop
  let sections := headerStr ++ itemStrs
  String.intercalate "\n\n" (sections.filter (· ≠ "")) ++ "\n"

end Continuity.Codegen.AST.Starlark
