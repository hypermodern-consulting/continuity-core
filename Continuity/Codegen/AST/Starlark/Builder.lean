import Continuity.Codegen.AST.Starlark.Ast

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "No, man," Bobby said, "it's not about what you see at the end.
      It's about the builder itself. You feed it one shape at a time —
      a varname here, a kwarg there, maybe a list literal or two — and
      it just... accumulates. Every modification writes into the same
      store, knitting the structure from the inside out. By the time the
      last instruction drops, the file is already whole."

                                                                      — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Starlark

/-
  Builder DSL for ergonomic Starlark AST construction.

  The raw `SFile` / `STop` / `SStmt` / `SExpr` constructors are precise
  but verbose. This module provides a statement builder monad (`StmtM`)
  and expression shortcuts (`E`) so codegen functions can assemble
  `.bzl` file bodies in a `do` block that reads close to the output.

  Builder → AST → Render. Same law as `Dhall` / `Haskell` / `Cpp`.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                   // expression // shortcuts
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- one-liner expression constructors. same role as `E` in `Haskell` / `C` in `Cpp`.

namespace E

def str (s : String) : SExpr := .str s
def int (n : Int) : SExpr := .int n
def bool (b : Bool) : SExpr := .bool b
def none : SExpr := .none
def var (name : String) : SExpr := .var name
def dot (e : SExpr) (field : String) : SExpr := .dot e field
def call (func : SExpr) (args : List SExpr) : SExpr := .call func args []
def list (elems : List SExpr) : SExpr := .list elems
def dict (entries : List (SExpr × SExpr)) : SExpr := .dict entries
def binop (op : String) (l r : SExpr) : SExpr := .binop op l r

end E

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // statement // builder
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- accumulates starlark statements. use with `buildStmts do ...`
abbrev StmtM := StateM (List SStmt)

def stmtAssign (target : String) (value : SExpr) : StmtM Unit :=
  modify fun ss => ss ++ [.assign target value]

def stmtExpr (value : SExpr) : StmtM Unit :=
  modify fun ss => ss ++ [.expr value]

def stmtRet (value : SExpr) : StmtM Unit :=
  modify fun ss => ss ++ [.ret value]

def stmtComment (text : String) : StmtM Unit :=
  modify fun ss => ss ++ [.comment text]

-- run a statement builder, producing a list of statements
def buildStmts (m : StmtM Unit) : List SStmt :=
  let (_, stmts) := m.run []
  stmts

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- TODO[b7r6]: !! write real tests !!

end Continuity.Codegen.AST.Starlark
