import Continuity.Codec.Scanner

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                // continuity // codec // dhall
                                                                     lexer.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Dhall lexer — Scanner-based tokenizer for the Dhall value subset.

  This is NOT a full Dhall lexer. It handles the subset we emit and
  need to parse back: records, unions, lists, let chains, lambdas,
  merge, strings, naturals, booleans, identifiers. No imports, no
  multi-line text, no URL references.

  This is Scanner power applied to a real grammar.
-/

namespace Continuity.Codec.Dhall

open Continuity.Codec


/- ════════════════════════════════════════════════════════════════════════════════
                                                                     // tokens
   ════════════════════════════════════════════════════════════════════════════════ -/

inductive Tok where
  -- punctuation
  | lbrace | rbrace | langle | rangle | lbracket | rbracket | lparen | rparen
  | comma | dot | equals | colon | arrow | bar
  -- keywords
  | kLet | kIn | kIf | kThen | kElse
  | kMerge | kSome | kNone | kTrue | kFalse
  | kLambda | kForall | kType
  | kWith | kToMap | kAssert
  -- operators
  | opPrefer | opListAppend | opTextAppend
  | opBoolOr | opBoolAnd | opBoolEq | opBoolNe
  | opNatPlus | opNatTimes | opEquiv
  -- literals
  | nat (n : Nat)
  | str (s : String)
  -- identifiers
  | ident (name : String)
  deriving Repr, DecidableEq, Inhabited


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // lexer helpers
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Is this byte valid in a Dhall identifier? a-z A-Z 0-9 _ - / -/
private def isIdentByte (b : UInt8) : Bool :=
  isAlphaNum b || b == 0x5F || b == 0x2D || b == 0x2F  -- _ - /

/-- Classify a scanned identifier as keyword or ident -/
private def classifyIdent (s : String) : Tok :=
  match s with
  | "let"    => Tok.kLet    | "in"     => Tok.kIn
  | "if"     => Tok.kIf     | "then"   => Tok.kThen
  | "else"   => Tok.kElse   | "merge"  => Tok.kMerge
  | "Some"   => Tok.kSome   | "None"   => Tok.kNone
  | "True"   => Tok.kTrue   | "False"  => Tok.kFalse
  | "forall" => Tok.kForall | "Type"   => Tok.kType
  | "Kind"   => Tok.kType   | "Sort"   => Tok.kType
  | "with"   => Tok.kWith   | "toMap"  => Tok.kToMap
  | "assert" => Tok.kAssert
  | name     => Tok.ident name

/-- Parse a natural number from bytes -/
private def bytesToNat (bs : ByteArray) : Nat :=
  bs.foldl (fun acc b => acc * 10 + (b.toNat - 0x30)) 0

/-- Parse an escaped string (between the quotes, already extracted) -/
private partial def parseStringContent (bs : ByteArray) : String :=
  let rec go (i : Nat) (acc : String) : String :=
    if i >= bs.size then acc
    else
      let b := bs.get! i
      if b == 0x5C then  -- backslash
        if i + 1 >= bs.size then acc.push (Char.ofNat b.toNat)
        else
          let next := bs.get! (i + 1)
          match next with
          | 0x6E => go (i + 2) (acc.push '\n')   -- \n
          | 0x74 => go (i + 2) (acc.push '\t')   -- \t
          | 0x5C => go (i + 2) (acc.push '\\')   -- \\
          | 0x22 => go (i + 2) (acc.push '"')     -- \"
          | _    => go (i + 2) (acc.push (Char.ofNat next.toNat))
      else
        go (i + 1) (acc.push (Char.ofNat b.toNat))
  go 0 ""


/- ════════════════════════════════════════════════════════════════════════════════
                                                                     // lexer
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Lex one token from the input. Returns (token, remaining bytes) or none. -/
private partial def lexOne (bs : Bytes) : Option (Tok × Bytes) :=
  -- skip whitespace and comments
  let bs := skipWS bs
  if bs.size == 0 then Option.none
  else
    let b := bs.get! 0
    -- single-char punctuation
    if b == 0x7B then Option.some (Tok.lbrace,   bs.extract 1 bs.size)    -- {
    else if b == 0x7D then Option.some (Tok.rbrace,   bs.extract 1 bs.size)    -- }
    else if b == 0x5B then Option.some (Tok.lbracket, bs.extract 1 bs.size)    -- [
    else if b == 0x5D then Option.some (Tok.rbracket, bs.extract 1 bs.size)    -- ]
    else if b == 0x28 then Option.some (Tok.lparen,   bs.extract 1 bs.size)    -- (
    else if b == 0x29 then Option.some (Tok.rparen,   bs.extract 1 bs.size)    -- )
    else if b == 0x2C then Option.some (Tok.comma,    bs.extract 1 bs.size)    -- ,
    else if b == 0x2A then Option.some (Tok.opNatTimes, bs.extract 1 bs.size)  -- *
    else if b == 0x23 then Option.some (Tok.opListAppend, bs.extract 1 bs.size) -- #
    -- dot
    else if b == 0x2E then Option.some (Tok.dot, bs.extract 1 bs.size)
    -- arrow: → or ->
    else if b == 0xE2 && bs.size >= 3 && bs.get! 1 == 0x86 && bs.get! 2 == 0x92 then
      Option.some (Tok.arrow, bs.extract 3 bs.size)  -- → (UTF-8: E2 86 92)
    else if b == 0x2D && bs.size >= 2 && bs.get! 1 == 0x3E then
      Option.some (Tok.arrow, bs.extract 2 bs.size)  -- ->
    -- lambda: λ or \
    else if b == 0xCE && bs.size >= 2 && bs.get! 1 == 0xBB then
      Option.some (Tok.kLambda, bs.extract 2 bs.size)  -- λ (UTF-8: CE BB)
    else if b == 0x5C then Option.some (Tok.kLambda, bs.extract 1 bs.size)  -- \
    -- forall: ∀
    else if b == 0xE2 && bs.size >= 3 && bs.get! 1 == 0x88 && bs.get! 2 == 0x80 then
      Option.some (Tok.kForall, bs.extract 3 bs.size)  -- ∀ (UTF-8: E2 88 80)
    -- multi-char operators (order matters: === before ==, // before /)
    else if b == 0x3D && bs.size >= 3 && bs.get! 1 == 0x3D && bs.get! 2 == 0x3D then
      Option.some (Tok.opEquiv, bs.extract 3 bs.size)     -- ===
    else if b == 0x3D && bs.size >= 2 && bs.get! 1 == 0x3D then
      Option.some (Tok.opBoolEq, bs.extract 2 bs.size)    -- ==
    else if b == 0x3D then Option.some (Tok.equals, bs.extract 1 bs.size) -- =
    else if b == 0x21 && bs.size >= 2 && bs.get! 1 == 0x3D then
      Option.some (Tok.opBoolNe, bs.extract 2 bs.size)    -- !=
    else if b == 0x2F && bs.size >= 2 && bs.get! 1 == 0x2F then
      Option.some (Tok.opPrefer, bs.extract 2 bs.size)    -- //
    else if b == 0x7C && bs.size >= 2 && bs.get! 1 == 0x7C then
      Option.some (Tok.opBoolOr, bs.extract 2 bs.size)    -- ||
    else if b == 0x7C then Option.some (Tok.bar, bs.extract 1 bs.size) -- |
    else if b == 0x26 && bs.size >= 2 && bs.get! 1 == 0x26 then
      Option.some (Tok.opBoolAnd, bs.extract 2 bs.size)   -- &&
    else if b == 0x2B && bs.size >= 2 && bs.get! 1 == 0x2B then
      Option.some (Tok.opTextAppend, bs.extract 2 bs.size) -- ++
    -- colon
    else if b == 0x3A then Option.some (Tok.colon, bs.extract 1 bs.size)
    -- + (but not ++) — already handled above
    else if b == 0x2B then Option.some (Tok.opNatPlus, bs.extract 1 bs.size)
    -- < > for union types
    else if b == 0x3C then Option.some (Tok.langle, bs.extract 1 bs.size)
    
    else if b == 0x3E then Option.some (Tok.rangle, bs.extract 1 bs.size)
    -- string literal
    else if b == 0x22 then
      -- scan until unescaped closing quote
      let rest := bs.extract 1 bs.size
      match scanString rest with
      | Option.some (content, remaining) =>
        Option.some (Tok.str (parseStringContent content), remaining)
      | Option.none => Option.none
    -- natural number
    else if isDigit b then
      let numBytes := takeWhile bs isDigit
      let rest := bs.extract numBytes.size bs.size
      Option.some (Tok.nat (bytesToNat numBytes), rest)
    -- identifier or keyword
    else if isAlpha b || b == 0x5F then
      let identBytes := takeWhile bs isIdentByte
      let name := String.fromUTF8! identBytes
      let rest := bs.extract identBytes.size bs.size
      Option.some (classifyIdent name, rest)
    else
      Option.none  -- unrecognized byte
where
  /-- Skip whitespace and line comments -/
  skipWS (bs : Bytes) : Bytes :=
    let rec go (bs : Bytes) : Bytes :=
      if bs.size == 0 then bs
      else
        let b := bs.get! 0
        if isWhitespace b then go (bs.extract 1 bs.size)
        else if b == 0x2D && bs.size >= 2 && bs.get! 1 == 0x2D then
          -- line comment: skip to newline
          match findByte LF bs with
          | Option.some idx => go (bs.extract (idx + 1) bs.size)
          | Option.none     => ByteArray.empty
        else if b == 0x7B && bs.size >= 2 && bs.get! 1 == 0x2D then
          -- block comment: skip to -}
          match findBlockEnd (bs.extract 2 bs.size) with
          | Option.some rest => go rest
          | Option.none      => ByteArray.empty
        else bs
    go bs
  /-- Find end of block comment -} -/
  findBlockEnd (bs : Bytes) : Option Bytes :=
    let rec go (i : Nat) : Option Bytes :=
      if i + 1 >= bs.size then Option.none
      else if bs.get! i == 0x2D && bs.get! (i + 1) == 0x7D then
        Option.some (bs.extract (i + 2) bs.size)
      else go (i + 1)
    go 0
  /-- Take bytes while predicate holds -/
  takeWhile (bs : Bytes) (p : UInt8 → Bool) : Bytes :=
    let rec go (i : Nat) : Nat :=
      if i < bs.size && p (bs.get! i) then go (i + 1) else i
    bs.extract 0 (go 0)
  /-- Scan a string body (after opening quote), handling escapes -/
  scanString (bs : Bytes) : Option (ByteArray × Bytes) :=
    let rec go (i : Nat) : Option (ByteArray × Bytes) :=
      if i >= bs.size then Option.none
      else
        let b := bs.get! i
        if b == 0x22 then  -- closing quote
          Option.some (bs.extract 0 i, bs.extract (i + 1) bs.size)
        else if b == 0x5C && i + 1 < bs.size then  -- escape
          go (i + 2)
        else go (i + 1)
    go 0

/-- Tokenize entire input into a list of tokens. -/
partial def tokenize (bs : Bytes) : List Tok :=
  let rec go (bs : Bytes) (acc : List Tok) : List Tok :=
    match lexOne bs with
    | Option.some (tok, rest) => go rest (tok :: acc)
    | Option.none             => acc.reverse
  go bs []


/- ════════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════════ -/

-- basic tokenization
#eval tokenize "{ name = \"hello\" }".toUTF8
#eval tokenize "let x = 42 in x".toUTF8
#eval tokenize "< A | B | C >.A".toUTF8
#eval tokenize "[ 1, 2, 3 ]".toUTF8
#eval tokenize "True".toUTF8
#eval tokenize "Some 42".toUTF8


end Continuity.Codec.Dhall
