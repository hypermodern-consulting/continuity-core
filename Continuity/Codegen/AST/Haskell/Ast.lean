set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Machine dreams hold a special vertigo." The engineers who came
      after could still feel it, when the architecture grew too deep,
      when the types nested past any reasonable depth, when one looked
      into the mutual recursion and saw the mutual recursion looking
      back. They told themselves there was a bottom — that at some level
      the constructors terminated, that the patterns resolved to atoms,
      that the do-notation unwound to a flat sequence of statements.
      But in the small hours, running the renderer across a thousand-line
      module, they were not so sure.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codegen.AST.Haskell

/-
  haskell AST — abstract syntax for a substantial subset of haskell 2010
  plus common `GHC` extensions.

  four distinct syntactic categories, defined in dependency order:
    1. `HsType` — types, including promoted and constrained
    2. `HsPat`  — patterns for case/function definitions
    3. `HsExpr` + `DoStmt` — expressions and do-notation (mutual)
    4. `HsDecl` — declarations, imports, pragmas

  these assemble into `HsModule`, which is a complete .hs file.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                       // types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive HsType where
  -- `Int`, `ByteString`, `Word64`
  | con (name : String)
  -- `Data.ByteString.ByteString`
  | qual (moduleName : String) (name : String)
  -- `a`, `m`
  | var (name : String)
  -- `Maybe Int`, `Get NixString`
  | app (fn : HsType) (arg : HsType)
  -- `Int -> Bool`
  | arrow (domain : HsType) (codomain : HsType)
  -- `[Int]`
  | list (elem : HsType)
  -- `(Int, Bool, String)`
  | tuple (elems : List HsType)
  -- `()`
  | unit
  -- `(Show a, Eq a) => a -> String`
  | constrained (constraints : List HsType) (body : HsType)
  -- `forall a b. a -> b -> a`
  | forallT (vars : List String) (body : HsType)
  -- `'[GLNet, GLCrypto]` — type-level promoted list
  | promotedList (elems : List HsType)
  -- `(a -> b)` — disambiguation
  | parens (inner : HsType)
  -- `a :+: b` — type operators
  | infixT (op : String) (lhs : HsType) (rhs : HsType)
  -- `"hello"` — `Symbol` kind string literal
  | stringT (value : String)
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                    // patterns
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive HsPat where
  -- `x`
  | var (name : String)
  -- `Just x`, `NixString content`
  | con (name : String) (args : List HsPat)
  -- `_`
  | wild
  -- `42`
  | litInt (value : Int)
  -- `"hello"`
  | litStr (value : String)
  -- `xs@(x:rest)`
  | as (name : String) (inner : HsPat)
  -- `(a, b, c)`
  | tuple (elems : List HsPat)
  -- `[x, y]`
  | listPat (elems : List HsPat)
  -- `NixString { nixStringContent = content }`
  | record (con : String) (fields : List (String × HsPat))
  -- `!x`
  | bang (inner : HsPat)
  -- `(pat)`
  | parens (inner : HsPat)
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // expressions + do-notation
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `HsExpr` and `DoStmt` are mutually recursive: expressions contain do-blocks,
-- do-blocks contain expressions. they must be defined in a mutual block.

mutual

inductive DoStmt where
  -- `pat <- action`
  | bind (pat : HsPat) (expr : HsExpr)
  -- `let pat = expr`
  | letStmt (pat : HsPat) (expr : HsExpr)
  -- bare expression: `pure x`, `putStrLn "hello"`
  | expr (e : HsExpr)

inductive HsExpr where
  -- literals
  | litInt (value : Int)
  | litStr (value : String)
  | litChar (value : Char)
  | list (elems : List HsExpr)
  | tuple (elems : List HsExpr)
  | unit

  -- references
  -- `x`, `getWord64le`
  | var (name : String)
  -- `Just`, `NixString`, `True`
  | con (name : String)
  -- `BS.length`, `Data.Map.empty`
  | qual (moduleName : String) (name : String)

  -- application
  -- `f x`
  | app (fn : HsExpr) (arg : HsExpr)
  -- `x + y`, `` x `mod` y ``
  | infix_ (op : String) (lhs : HsExpr) (rhs : HsExpr)
  -- `(+ 1)` or `(1 +)`. `isLeft = true` means value is on the left
  | section (op : String) (side : HsExpr) (isLeft : Bool)

  -- lambda
  -- `\x y -> body`
  | lam (params : List HsPat) (body : HsExpr)

  -- binding
  -- `let { bindings } in body`
  | letIn (bindings : List (HsPat × HsExpr)) (body : HsExpr)
  -- `if c then t else f`
  | ite (cond : HsExpr) (thenBranch : HsExpr) (elseBranch : HsExpr)
  -- `case x of { pat -> expr; ... }`
  | case_ (scrutinee : HsExpr) (alts : List (HsPat × HsExpr))
  -- `do { stmts }`
  | do_ (stmts : List DoStmt)

  -- type annotation
  -- `expr :: Type`
  | typed (expr : HsExpr) (ty : HsType)

  -- record
  -- `Foo { bar = 1, baz = "hello" }`
  | recordCon (con : String) (fields : List (String × HsExpr))
  -- `r { bar = 42 }`
  | recordUpdate (expr : HsExpr) (fields : List (String × HsExpr))

  -- parenthesized
  | parens (inner : HsExpr)

  -- special
  -- negation: `-x`
  | negate (inner : HsExpr)

end

-- n.b. deriving for mutual inductives must come after the mutual block
deriving instance Repr for DoStmt
deriving instance Repr for HsExpr

instance : Inhabited HsExpr where default := HsExpr.unit
instance : Inhabited DoStmt where default := DoStmt.expr HsExpr.unit

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // declarations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- right-hand side of a function clause: simple body or guarded
inductive RHS where
  -- `= expr`
  | simple (body : HsExpr)
  -- `| cond1 = body1 \n | cond2 = body2`
  | guarded (guards : List (HsExpr × HsExpr))
  deriving Repr, Inhabited

-- a function clause: LHS patterns, RHS, optional where
structure FunClause where
  patterns : List HsPat
  rhs : RHS
  whereBinds : List (String × HsExpr)
  deriving Repr, Inhabited

-- data constructor
inductive DataCon where
  -- `Just a`, `Left a`
  | positional (name : String) (fields : List HsType)
  -- `NixString { nixStringContent :: ByteString }`
  | record (name : String) (fields : List (String × HsType))
  deriving Repr, Inhabited

-- what to import from a module
inductive ImportSpec where
  | all
  -- `(ByteString, pack, unpack)`
  | only (names : List String)
  -- `hiding (map, filter)`
  | hiding (names : List String)
  deriving Repr, Inhabited

-- top-level declarations
inductive HsDecl where
  -- `{-# LANGUAGE StrictData #-}`
  | pragma (kind : String) (value : String)
  -- import statement
  | import_ (moduleName : String) (qualified : Bool)
            (alias : Option String) (spec : ImportSpec)
  -- `foo :: Int -> Bool`
  | typeSig (name : String) (ty : HsType)
  -- function definition with clauses
  | funDef (name : String) (clauses : List FunClause)
  -- `data Foo a = Bar a | Baz String deriving (Show, Eq)`
  | dataDef (name : String) (params : List String)
            (constructors : List DataCon) (deriving_ : List String)
  -- `newtype Foo = Foo Int deriving (Show)`
  | newtypeDef (name : String) (params : List String)
               (con : DataCon) (deriving_ : List String)
  -- `type Foo = Bar Int`
  | typeAlias (name : String) (params : List String) (body : HsType)
  -- class instance definition
  | instanceDef (constraints : List HsType) (head : HsType)
                (methods : List (String × List FunClause))
  -- `-- comment text`
  | comment (text : String)
  -- blank separator line
  | blank
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // module
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a complete `Haskell` source file
structure HsModule where
  name : String
  exports : Option (List String)
  decls : List HsDecl
  deriving Repr, Inhabited

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                 // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

namespace HsType

def apps (fn : HsType) (args : List HsType) : HsType :=
  args.foldl (fun acc a => HsType.app acc a) fn

def io (inner : HsType) : HsType := HsType.app (HsType.con "IO") inner
def maybe (inner : HsType) : HsType := HsType.app (HsType.con "Maybe") inner

end HsType

namespace HsExpr

def apps (fn : HsExpr) (args : List HsExpr) : HsExpr :=
  args.foldl (fun acc a => HsExpr.app acc a) fn

def pure_ (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "pure") x
def return_ (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "return") x
def fromIntegral (x : HsExpr) : HsExpr := HsExpr.app (HsExpr.var "fromIntegral") x

end HsExpr

namespace HsDecl

-- `import Module (names...)`
def importOnly (moduleName : String) (names : List String) : HsDecl :=
  HsDecl.import_ moduleName false Option.none (ImportSpec.only names)

-- `import qualified Module as Alias`
def importQualified (moduleName : String) (alias : String) : HsDecl :=
  HsDecl.import_ moduleName true (Option.some alias) ImportSpec.all

-- simple single-clause function
def simpleFun (name : String) (pats : List HsPat) (body : HsExpr) : HsDecl :=
  HsDecl.funDef name [{ patterns := pats, rhs := RHS.simple body, whereBinds := [] }]

end HsDecl

end Continuity.Codegen.AST.Haskell
