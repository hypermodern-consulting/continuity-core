import Continuity.Codec.Dhall.Lexer
import Continuity.Codegen.AST.Dhall.Ast
import Continuity.Codegen.AST.Dhall.Render

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The box was a universe, a poem, frozen on the boundaries of human
      experience. He'd always accepted the intelligence that moved through
      the matrix, never thinking to question its shape. But now the grammar
      itself was peeling back, revealing the recursive structure beneath:
      let-bindings that rhymed across levels, lambdas that folded space
      like origami, types bleeding into terms and terms into types until
      the distinction between map and territory dissolved entirely."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Dhall

open Continuity.Codegen.AST.Dhall

/-
  Dhall parser — recursive descent from tokens to `Expr`.

  This is Parser power applied: LL(1) recursive descent over the token
  stream produced by `Lexer.tokenize`. Builds the same `Expr` type that
  the emitter produces, so the roundtrip is structural.

  Grammar (Dhall value subset):

    expr       = letExpr | lambdaExpr | ifExpr | mergeExpr | annot
    letExpr    = "let" IDENT (":" expr)? "=" expr "in" expr
    lambdaExpr = "λ" "(" IDENT ":" expr ")" "→" expr
    ifExpr     = "if" expr "then" expr "else" expr
    mergeExpr  = "merge" atom atom
    annot      = appExpr (":" expr)?
    appExpr    = selectExpr+
    selectExpr = atom ("." IDENT)*
    atom       = NAT | STR | "True" | "False" | "Some" atom | "None" atom
               | IDENT | record | list | union | "(" expr ")"
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // parse // monad
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

abbrev P (α : Type) := List Tok → Option (α × List Tok)

-- peek at the next token without consuming.
private def peek : P Tok
  | t :: ts => Option.some (t, t :: ts)
  | []      => Option.none

-- consume a specific token.
private def expect (expected : Tok) : P Unit
  | t :: ts => if t == expected then Option.some ((), ts) else Option.none
  | []      => Option.none

-- consume an identifier, returning its name.
private def ident : P String
  | Tok.ident name :: ts => Option.some (name, ts)
  | _                     => Option.none

-- consume a natural number.
private def nat : P Nat
  | Tok.nat n :: ts => Option.some (n, ts)
  | _                => Option.none

-- consume a string literal.
private def str : P String
  | Tok.str s :: ts => Option.some (s, ts)
  | _                => Option.none

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // recursive // descent
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

mutual

-- parse an expression (top level).
partial def parseExpr : P Expr
  | Tok.kLet :: ts      => parseLet ts
  | Tok.kLambda :: ts   => parseLambda ts
  | Tok.kForall :: ts   => parseForall ts
  | Tok.kIf :: ts       => parseIf ts
  | Tok.kMerge :: ts    => parseMerge ts
  | Tok.kAssert :: ts   => parseAssert ts
  | ts                  => parseAnnot ts

-- `let name (: ty)? = value in body`
partial def parseLet (ts : List Tok) : Option (Expr × List Tok) := do
  let (name, ts) ← ident ts
  let (ty, ts) ← match ts with
    | Tok.colon :: ts' => do
      let (t, ts'') ← parseExpr ts'
      pure (Option.some t, ts'')
    | _ => pure (Option.none, ts)
  let ((), ts) ← expect Tok.equals ts
  let (value, ts) ← parseExpr ts
  let ((), ts) ← expect Tok.kIn ts
  let (body, ts) ← parseExpr ts
  pure (Expr.letIn name ty value body, ts)

-- `λ(param : type) → body`
partial def parseLambda (ts : List Tok) : Option (Expr × List Tok) := do
  let ((), ts) ← expect Tok.lparen ts
  let (param, ts) ← ident ts
  let ((), ts) ← expect Tok.colon ts
  let (paramTy, ts) ← parseExpr ts
  let ((), ts) ← expect Tok.rparen ts
  let ((), ts) ← expect Tok.arrow ts
  let (body, ts) ← parseExpr ts
  pure (Expr.lambda param paramTy body, ts)

-- `∀(param : type) → body`
partial def parseForall (ts : List Tok) : Option (Expr × List Tok) := do
  let ((), ts) ← expect Tok.lparen ts
  let (param, ts) ← ident ts
  let ((), ts) ← expect Tok.colon ts
  let (paramTy, ts) ← parseExpr ts
  let ((), ts) ← expect Tok.rparen ts
  let ((), ts) ← expect Tok.arrow ts
  let (body, ts) ← parseExpr ts
  pure (Expr.forallE param paramTy body, ts)

-- `if cond then thenBranch else elseBranch`
partial def parseIf (ts : List Tok) : Option (Expr × List Tok) := do
  let (cond, ts) ← parseExpr ts
  let ((), ts) ← expect Tok.kThen ts
  let (thn, ts) ← parseExpr ts
  let ((), ts) ← expect Tok.kElse ts
  let (els, ts) ← parseExpr ts
  pure (Expr.ite cond thn els, ts)

-- `merge handler union`
partial def parseMerge (ts : List Tok) : Option (Expr × List Tok) := do
  let (handler, ts) ← parseAtom ts
  let (union, ts) ← parseAtom ts
  pure (Expr.merge handler union Option.none, ts)

-- `assert : expr`
partial def parseAssert (ts : List Tok) : Option (Expr × List Tok) := do
  let ((), ts) ← expect Tok.colon ts
  let (body, ts) ← parseExpr ts
  pure (Expr.assert body, ts)

-- expression with optional type annotation: `expr : type`
partial def parseAnnot (ts : List Tok) : Option (Expr × List Tok) := do
  let (e, ts) ← parseAppExpr ts
  match ts with
  | Tok.colon :: ts' => do
    let (ty, ts'') ← parseExpr ts'
    pure (Expr.annot e ty, ts'')
  | _ => pure (e, ts)

-- application: one or more atoms left-associated.
-- `f x y` = `app (app f x) y`
partial def parseAppExpr (ts : List Tok) : Option (Expr × List Tok) := do
  let (first, ts) ← parseSelectExpr ts
  let rec go (acc : Expr) (ts : List Tok) : Expr × List Tok :=
    match parseSelectExpr ts with
    | Option.some (arg, ts') => go (Expr.app acc arg) ts'
    | Option.none            => (acc, ts)
  pure (go first ts)

-- field selection: `expr.field1.field2`
partial def parseSelectExpr (ts : List Tok) : Option (Expr × List Tok) := do
  let (e, ts) ← parseAtom ts
  let rec go (acc : Expr) (ts : List Tok) : Expr × List Tok :=
    match ts with
    | Tok.dot :: Tok.ident name :: ts' => go (Expr.field acc name) ts'
    | Tok.dot :: Tok.lbrace :: ts' =>
      match parseIdentList ts' with
      | Option.some (names, ts'') => go (Expr.project acc names) ts''
      | Option.none => (acc, ts)
    | _ => (acc, ts)
  pure (go e ts)

-- parse a single atom.
partial def parseAtom (ts : List Tok) : Option (Expr × List Tok) :=
  match ts with
  | Tok.nat n :: ts'       => Option.some (Expr.natural n, ts')
  | Tok.str s :: ts'       => Option.some (Expr.text s, ts')
  | Tok.kTrue :: ts'       => Option.some (Expr.bool true, ts')
  | Tok.kFalse :: ts'      => Option.some (Expr.bool false, ts')
  | Tok.kType :: ts'       => Option.some (Expr.builtin "Type", ts')
  | Tok.kSome :: ts' => do
    let (val, ts'') ← parseAtom ts'
    pure (Expr.some val, ts'')
  | Tok.kNone :: ts' => do
    let (ty, ts'') ← parseAtom ts'
    pure (Expr.none ty, ts'')
  | Tok.ident name :: ts' =>
    match ts' with
    | Tok.dot :: Tok.ident field :: ts'' =>
      Option.some (Expr.field (Expr.var name) field, ts'')
    | _ => Option.some (Expr.var name, ts')
  -- record or record type: `{ ... }`
  | Tok.lbrace :: ts' => parseRecordish ts'
  -- list: `[ ... ]`
  | Tok.lbracket :: ts' => parseList ts'
  -- union: `< ... >`
  | Tok.langle :: ts' => parseUnion ts'
  -- parenthesized: `( expr )`
  | Tok.lparen :: ts' => do
    let (e, ts'') ← parseExpr ts'
    let ((), ts''') ← expect Tok.rparen ts''
    pure (e, ts''')
  | _ => Option.none

-- parse record literal `{ name = val, ... }` or record type `{ name : ty, ... }`
partial def parseRecordish (ts : List Tok) : Option (Expr × List Tok) :=
  match ts with
  -- empty record: `{=}`
  | Tok.equals :: Tok.rbrace :: ts' => Option.some (Expr.record [], ts')
  -- empty record type: `{}`
  | Tok.rbrace :: ts' => Option.some (Expr.recordType [], ts')
  -- peek at first field to decide record vs record type
  | Tok.ident name :: Tok.equals :: ts' => do
    let (val, ts'') ← parseExpr ts'
    let (rest, ts''') ← parseRecordFields ts''
    pure (Expr.record ((name, val) :: rest), ts''')
  | Tok.ident name :: Tok.colon :: ts' => do
    let (ty, ts'') ← parseExpr ts'
    let (rest, ts''') ← parseRecordTypeFields ts''
    pure (Expr.recordType ((name, ty) :: rest), ts''')
  | _ => Option.none

-- parse remaining record literal fields: `, name = val` until `}`
partial def parseRecordFields (ts : List Tok) : Option (List (String × Expr) × List Tok) :=
  match ts with
  | Tok.rbrace :: ts' => Option.some ([], ts')
  | Tok.comma :: Tok.ident name :: Tok.equals :: ts' => do
    let (val, ts'') ← parseExpr ts'
    let (rest, ts''') ← parseRecordFields ts''
    pure ((name, val) :: rest, ts''')
  | _ => Option.none

-- parse remaining record type fields: `, name : ty` until `}`
partial def parseRecordTypeFields (ts : List Tok) : Option (List (String × Expr) × List Tok) :=
  match ts with
  | Tok.rbrace :: ts' => Option.some ([], ts')
  | Tok.comma :: Tok.ident name :: Tok.colon :: ts' => do
    let (ty, ts'') ← parseExpr ts'
    let (rest, ts''') ← parseRecordTypeFields ts''
    pure ((name, ty) :: rest, ts''')
  | _ => Option.none

-- TODO[b7r6]: !! this is too nested for a language without a formatter !!

-- parse list: items until `]`, optional type annotation
partial def parseList (ts : List Tok) : Option (Expr × List Tok) :=
  match ts with
  | Tok.rbracket :: ts' =>
    match ts' with
    | Tok.colon :: ts'' => do
      let (ty, ts''') ← parseExpr ts''
      pure (Expr.list [] (Option.some ty), ts''')
    | _ => Option.some (Expr.list [] Option.none, ts')
  | _ => do
    let (first, ts') ← parseExpr ts
    let (rest, ts'') ← parseListTail ts'
    pure (Expr.list (first :: rest) Option.none, ts'')

-- parse remaining list items: `, expr` until `]`
partial def parseListTail (ts : List Tok) : Option (List Expr × List Tok) :=
  match ts with
  | Tok.rbracket :: ts' => Option.some ([], ts')
  | Tok.comma :: ts' => do
    let (e, ts'') ← parseExpr ts'
    let (rest, ts''') ← parseListTail ts''
    pure (e :: rest, ts''')
  | _ => Option.none

-- parse union type: `< A | B : T | C >` with optional `.tag`
partial def parseUnion (ts : List Tok) : Option (Expr × List Tok) := do
  let (alts, ts) ← parseUnionAlts ts
  match ts with
  | Tok.dot :: Tok.ident tag :: ts' =>
    Option.some (Expr.unionVal "" alts tag Option.none, ts')
  | _ => Option.some (Expr.unionType alts, ts)

-- TODO[b7r6]: !! this is too nested for a language without a formatter !!

-- parse union alternatives: `A | B : T | C` until `>`
partial def parseUnionAlts (ts : List Tok) : Option (List (String × Option Expr) × List Tok) :=
  match ts with
  | Tok.rangle :: ts' => Option.some ([], ts')
  | Tok.ident name :: ts' =>
    let (payload, ts'') := match ts' with
      | Tok.colon :: ts'' =>
        match parseExpr ts'' with
        | Option.some (ty, ts''') => (Option.some ty, ts''')
        | Option.none => (Option.none, ts')
      | _ => (Option.none, ts')
    match ts'' with
    | Tok.bar :: ts''' => do
      let (rest, ts'''') ← parseUnionAlts ts'''
      pure ((name, payload) :: rest, ts'''')
    | Tok.rangle :: ts''' =>
      Option.some ([(name, payload)], ts''')
    | _ => Option.none
  | _ => Option.none

-- parse comma-separated identifiers until `}`
partial def parseIdentList (ts : List Tok) : Option (List String × List Tok) :=
  match ts with
  | Tok.rbrace :: ts' => Option.some ([], ts')
  | Tok.ident name :: Tok.rbrace :: ts' => Option.some ([name], ts')
  | Tok.ident name :: Tok.comma :: ts' => do
    let (rest, ts'') ← parseIdentList ts'
    pure (name :: rest, ts'')
  | _ => Option.none

end

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // public // api
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- parse a Dhall expression from a string.
def parse (input : String) : Option Expr := do
  let tokens := tokenize input.toUTF8
  -- TODO[b7r6]: !! `remaining` sounds important !!
  let (expr, _) ← parseExpr tokens
  pure expr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                        // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- TODO[b7r6]: !! write real tests !!

-- -- atoms
-- #eval parse "42"
-- #eval parse "\"hello\""
-- #eval parse "True"
-- #eval parse "Some 42"

-- -- record
-- #eval parse "{ name = \"hello\", version = 1 }"

-- -- list
-- #eval parse "[ 1, 2, 3 ]"

-- -- let chain
-- #eval parse "let x = 42 in x"

-- -- lambda
-- #eval parse "λ(x : Natural) → x"

-- -- union type
-- #eval parse "< A | B | C >"

-- -- field access
-- #eval parse "config.name"

-- -- the money shot: parse our own emitted Dhall
-- #eval do
--   let original := Continuity.Codegen.AST.Dhall.Expr.record [
--     ("name", Continuity.Codegen.AST.Dhall.Expr.str "hello"),
--     ("version", Continuity.Codegen.AST.Dhall.Expr.natural 1)
--   ]
--   let rendered := Continuity.Codegen.AST.Dhall.render original
--   let parsed ← parse rendered
--   pure (repr parsed)

end Continuity.Codec.Dhall
