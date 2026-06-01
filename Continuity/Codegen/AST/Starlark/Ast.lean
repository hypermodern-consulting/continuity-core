set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "How'd it grab Jaylene?"

      "It was a construct, Jaylene. A deliberate construct. Somebody built
      it. And the structure, the architecture of the thing — whoever
      designed it knew exactly what they were doing. They were building
      something meant to interface with the biochip protocol at a level
      we hadn't even considered."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Starlark

/-
  Starlark AST — sufficient for toolchain `.bzl` codegen.

  Not a complete starlark parser/AST. Covers what the toolchain
  implementations actually use: config reads, flag construction,
  provider instantiation, rule definitions.

  Builder → AST → render. Same law as `Dhall`.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // core // expressions
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- starlark expression.
inductive SExpr where
  -- string literal: `"hello"`
  | str (value : String)

  -- triple-quoted string: `"""..."""`
  | strBlock (value : String)

  -- integer literal: `42`
  | int (value : Int)

  -- boolean: `True` / `False`
  | bool (value : Bool)

  -- `None`
  | none

  -- variable reference: `ctx`, `cc`, `MANDATORY_GHC_FLAGS`
  | var (name : String)

  -- attribute access: `ctx.attrs.name`, `info.olean_dir`
  | dot (expr : SExpr) (field : String)

  -- index: `x[Key]`
  | index (expr : SExpr) (key : SExpr)

  -- function/constructor call: `f(args..., kwarg=val, ...)`
  | call (func : SExpr) (args : List SExpr) (kwargs : List (String × SExpr))

  -- method call: `obj.method(args...)` — sugar for call(dot(obj,method),...)
  | methodCall (obj : SExpr) (method : String) (args : List SExpr) (kwargs : List (String × SExpr))

  -- list literal: `[a, b, c]`
  | list (elements : List SExpr)

  -- dict literal: `{"key": val, ...}`
  | dict (entries : List (SExpr × SExpr))

  -- binary op: `a + b`, `a and b`, etc.
  | binop (op : String) (lhs : SExpr) (rhs : SExpr)

  -- unary op: `not x`
  | unop (op : String) (expr : SExpr)

  -- comparison: `a == b`, `a != None`, `a in b`
  | cmp (op : String) (lhs : SExpr) (rhs : SExpr)

  -- ternary: `x if cond else y`
  | ternary (thenExpr : SExpr) (cond : SExpr) (elseExpr : SExpr)

  -- format string piece: `"prefix" + expr + "suffix"`
  | concat (parts : List SExpr)

  -- string format: `"{}.so".format(name)` — rendered as method call
  | format (template : String) (args : List SExpr)

  -- raw expression text (escape hatch, use sparingly)
  | raw (text : String)

  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // core // statements
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- starlark statement.
inductive SStmt where
  -- assignment: `x = expr`
  | assign (target : String) (value : SExpr)

  -- augmented assignment: `x += expr`, `x.append(expr)`
  | augAssign (target : String) (op : String) (value : SExpr)

  -- expression statement: `cmd.add(flags)`
  | expr (value : SExpr)

  -- return: `return expr`
  | ret (value : SExpr)

  -- if/elif/else block
  | ifStmt (branches : List (SExpr × List SStmt)) (elseBranch : List SStmt)

  -- for loop: `for x in iterable:`
  | forStmt (var : String) (iterable : SExpr) (body : List SStmt)

  -- block comment
  | comment (text : String)

  -- blank line
  | blank

  -- raw statement text (escape hatch)
  | raw (text : String)

  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // core // top-level
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a function parameter with optional type annotation and default.
structure SParam where
  name    : String
  type    : Option String := Option.none
  default : Option SExpr  := Option.none
  deriving Repr, Inhabited

-- top-level starlark definition.
inductive STop where
  -- `load("path.bzl", "sym1", "sym2")`
  | load (path : String) (symbols : List String)

  -- global assignment: `X = expr`
  | globalAssign (name : String) (value : SExpr)

  -- `provider(fields = {...})`
  | provider (name : String) (fields : List (String × String))

  -- function definition: `def name(params): body`
  | funcDef (name : String) (params : List SParam)
      (retType : Option String) (doc : Option String) (body : List SStmt)

  -- `name = rule(impl = ..., attrs = {...}, ...)`
  | ruleDef (name : String) (implName : String) (isToolchain : Bool)
      (attrs : List (String × SExpr))

  -- section comment
  | comment (text : String)

  -- blank line
  | blank
  deriving Repr, Inhabited

-- a complete `.bzl` file.
structure SFile where
  header : String := ""
  items  : List STop := []
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // core // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

namespace SExpr

def strLit (s : String) : SExpr := .str s
def intLit (n : Int) : SExpr := .int n
def true_ : SExpr := .bool true
def false_ : SExpr := .bool false

-- `read_root_config("sect", "key", default)`
def readConfig (sect key : String) (default : SExpr) : SExpr :=
  .call (.var "read_root_config") [.str sect, .str key, default] []

-- `read_root_config("sect", "key", None)`
def readConfigOpt (sect key : String) : SExpr :=
  readConfig sect key .none

-- `RunInfo(args = [x])`
def runInfo (args : SExpr) : SExpr :=
  .call (.var "RunInfo") [] [("args", args)]

-- `DefaultInfo()`
def defaultInfo : SExpr :=
  .call (.var "DefaultInfo") [] []

-- `ctx.attrs.field`
def ctxAttr (field : String) : SExpr :=
  .dot (.dot (.var "ctx") "attrs") field

-- `ctx.actions.method(args...)`
def ctxAction (method : String) (args : List SExpr) (kwargs : List (String × SExpr)) : SExpr :=
  .methodCall (.dot (.var "ctx") "actions") method args kwargs

end SExpr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                        // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- TODO[b7r6]: !! write real tests !!

end Continuity.Codegen.AST.Starlark
