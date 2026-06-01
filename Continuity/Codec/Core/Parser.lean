import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "It was such an easy thing, death. He saw that now: it just
      happened. You weren't fighting it so much as you were reading
      it, parsing the syntax of your own dissolution just as you'd
      once learned to parse the ice, selecting the individual
      elements of a run and slotting each one into the exact
      sequence that would carry you home. The grammar of survival
      was never more than a few tokens deep, but you had to read
      them in the right order. One misplaced symbol and the whole
      parse collapsed into noise."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Parser
/-
  Parser — LL(k) grammar-based parsing for structured text.

  The most powerful level in the power hierarchy:

    `Box`     — LL(0) + dep, bidirectional, for binary formats
    `Scanner` — LL(0) + delimiter scan, one-way, for text/line protocols
    `Parser`  — LL(k), token-based, for structured text (JSON, config, DSLs)

  Key properties:
    - Token-based: lexer (`Scanner`) produces tokens, `Parser` consumes them
    - Fixed lookahead k: predictable O(n) performance
    - No backtracking: ordered choice, first match wins
    - Lookahead bound proven: `maxLookahead ≤ k`
    - Determinism by construction: `parse` is a function
-/

open Continuity.Codec.Core.Box
open Continuity.Codec.Core.Scanner
open Continuity.Codec.Core.Bytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // tokens
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- token with type tag, lexeme, and source offset.
structure Token (T : Type) where
  type : T
  lexeme : String
  offset : Nat
  deriving Repr

-- token stream: a list of tokens with a position cursor.
structure TokenStream (T : Type) where
  tokens : List (Token T)
  position : Nat
  deriving Repr

namespace TokenStream

def empty {T : Type} : TokenStream T := ⟨[], 0⟩
def fromList {T : Type} (ts : List (Token T)) : TokenStream T := ⟨ts, 0⟩

def peek {T : Type} (s : TokenStream T) : Option (Token T) :=
  s.tokens[s.position]?

def peekN {T : Type} (s : TokenStream T) (n : Nat) : Option (Token T) :=
  s.tokens[s.position + n]?

def advance {T : Type} (s : TokenStream T) : TokenStream T :=
  { s with position := s.position + 1 }

def isEof {T : Type} (s : TokenStream T) : Bool :=
  s.position >= s.tokens.length

def remaining {T : Type} (s : TokenStream T) : List (Token T) :=
  s.tokens.drop s.position

end TokenStream

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // parse result
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- parser result: success with remaining stream, or error with position.
inductive PResult (T : Type) (α : Type) where
  | ok : α → TokenStream T → PResult T α
  | err : String → Nat → PResult T α
  deriving Repr, Inhabited

namespace PResult

def map {T α β : Type} (f : α → β) : PResult T α → PResult T β
  | ok a s    => ok (f a) s
  | err msg p => err msg p

def bind {T α β : Type} (r : PResult T α) (f : α → TokenStream T → PResult T β) : PResult T β :=
  match r with
  | ok a s    => f a s
  | err msg p => err msg p

def isOk {T α : Type} : PResult T α → Bool
  | ok _ _ => true
  | _      => false

end PResult

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // parser
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a parser transforms a token stream into a value with bounded lookahead.
-- the `k` parameter bounds how many tokens can be examined before
-- committing to a parse. `maxLookahead ≤ k` is proven for every
-- parser. determinism is free — `parse` is a function.
structure Parser (T : Type) (α : Type) (k : Nat) where
  parse : TokenStream T → PResult T α
  maxLookahead : Nat := 0
  lookahead_bound : maxLookahead ≤ k := by omega

instance {T α : Type} {k : Nat} : Inhabited (Parser T α k) where
  default := ⟨fun _ => default, 0, Nat.zero_le k⟩

abbrev Parser1 (T : Type) (α : Type) := Parser T α 1
abbrev Parser2 (T : Type) (α : Type) := Parser T α 2

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // primitive parsers
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- always succeed with a value, consuming no tokens.
def Parser.pure {T α : Type} {k : Nat} (a : α) : Parser T α k where
  parse ts := .ok a ts

-- always fail.
def Parser.fail {T α : Type} {k : Nat} (msg : String) : Parser T α k where
  parse ts := .err msg ts.position

-- match a token of a specific type.
def Parser.token {T : Type} [DecidableEq T] [Repr T] (expected : T) : Parser1 T (Token T) where
  parse ts :=
    match ts.peek with
    | Option.some tok =>
      if tok.type == expected then .ok tok ts.advance
      else .err s!"expected {repr expected}, got {repr tok.type}" ts.position
    | Option.none => .err s!"expected {repr expected}, got EOF" ts.position
  maxLookahead := 1

-- match any token satisfying a predicate.
def Parser.satisfy {T : Type} (p : Token T → Bool) (desc : String) : Parser1 T (Token T) where
  parse ts :=
    match ts.peek with
    | Option.some tok =>
      if p tok then .ok tok ts.advance
      else .err s!"expected {desc}" ts.position
    | Option.none => .err s!"expected {desc}, got EOF" ts.position
  maxLookahead := 1

-- match any single token.
def Parser.anyToken {T : Type} : Parser1 T (Token T) where
  parse ts :=
    match ts.peek with
    | Option.some tok => .ok tok ts.advance
    | Option.none     => .err "unexpected EOF" ts.position
  maxLookahead := 1

-- match end of input.
def Parser.eof {T : Type} : Parser1 T Unit where
  parse ts :=
    if ts.isEof then .ok () ts
    else .err "expected EOF" ts.position
  maxLookahead := 1

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // lookahead
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- look ahead without consuming tokens.
def Parser.lookAhead {T α : Type} {k : Nat} (p : Parser T α k) : Parser T α k where
  parse ts :=
    match p.parse ts with
    | .ok a _    => .ok a ts
    | .err msg p => .err msg p

  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- succeed if parser fails (negative lookahead).
def Parser.notFollowedBy {T α : Type} {k : Nat} (p : Parser T α k) : Parser T Unit k where
  parse ts :=
    match p.parse ts with
    | .ok _ _  => .err "unexpected match" ts.position
    | .err _ _ => .ok () ts

  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- sequence: parse p1 then p2.
def Parser.seq {T α β : Type} {k : Nat} (p1 : Parser T α k) (p2 : Parser T β k) : Parser T (α × β) k where
  parse ts :=
    p1.parse ts |>.bind fun a ts' =>
      p2.parse ts' |>.map fun b => (a, b)

  maxLookahead := max p1.maxLookahead p2.maxLookahead
  lookahead_bound := Nat.max_le.mpr ⟨p1.lookahead_bound, p2.lookahead_bound⟩

-- map over parser result.
def Parser.map {T α β : Type} {k : Nat} (p : Parser T α k) (f : α → β) : Parser T β k where
  parse ts := p.parse ts |>.map f
  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- bind / flatMap.
def Parser.bind {T α β : Type} {k : Nat} (p : Parser T α k) (f : α → Parser T β k) : Parser T β k where
  parse ts :=
    p.parse ts |>.bind fun a ts' =>
      (f a).parse ts'

  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- ordered choice: try p1, if it fails without consuming, try p2.
def Parser.orElse {T α : Type} {k : Nat} (p1 : Parser T α k) (p2 : Parser T α k) : Parser T α k where

  parse ts :=
    match p1.parse ts with
    | .ok a ts'    => .ok a ts'
    | .err msg1 pos1 =>
      if pos1 == ts.position then p2.parse ts
      else .err msg1 pos1

  maxLookahead := max p1.maxLookahead p2.maxLookahead
  lookahead_bound := Nat.max_le.mpr ⟨p1.lookahead_bound, p2.lookahead_bound⟩

instance {T α : Type} {k : Nat} : OrElse (Parser T α k) where
  orElse p1 p2 := Parser.orElse p1 (p2 ())

-- optional: try parser, return none on non-consuming failure.
def Parser.optional {T α : Type} {k : Nat} (p : Parser T α k) : Parser T (Option α) k where
  parse ts :=
    match p.parse ts with
    | .ok a ts'   => .ok (Option.some a) ts'
    | .err _ pos  =>
      if pos == ts.position then .ok Option.none ts
      else .err "optional parser consumed input before failing" pos

  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- zero or more.
partial def Parser.many {T α : Type} {k : Nat} (p : Parser T α k) : Parser T (List α) k where
  parse ts :=
    match p.parse ts with
    | .ok a ts' =>
      if ts'.position == ts.position then
        .err "many: parser succeeded without consuming input" ts.position
      else
        match (Parser.many p).parse ts' with
        | .ok as ts'' => .ok (a :: as) ts''
        | .err _ _    => .ok [a] ts'
    | .err _ _ => .ok [] ts
  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- one or more.
def Parser.many1 {T α : Type} {k : Nat} (p : Parser T α k) : Parser T (List α) k where
  parse ts :=
    match p.parse ts with
    | .ok a ts' =>
      match (Parser.many p).parse ts' with
      | .ok as ts'' => .ok (a :: as) ts''
      | .err _ _    => .ok [a] ts'
    | .err msg pos => .err msg pos
  maxLookahead := p.maxLookahead
  lookahead_bound := p.lookahead_bound

-- between delimiters.
def Parser.between {T α : Type} {k : Nat}
    (left : Parser T Unit k) (right : Parser T Unit k) (p : Parser T α k) :
    Parser T α k where

  parse ts :=
    left.parse ts |>.bind fun () ts' =>
      p.parse ts' |>.bind fun a ts'' =>
        right.parse ts'' |>.map fun () => a

  maxLookahead := max (max left.maxLookahead right.maxLookahead) p.maxLookahead

  lookahead_bound := by
    apply Nat.max_le.mpr; constructor
    · exact Nat.max_le.mpr ⟨left.lookahead_bound, right.lookahead_bound⟩
    · exact p.lookahead_bound

-- TODO[b7r6]: !! this is too nested for a language without a formatter !!

-- items separated by delimiter.
def Parser.sepBy {T α : Type} {k : Nat}
    (item : Parser T α k) (sep : Parser T Unit k) : Parser T (List α) k where

  parse ts :=
    match item.parse ts with
    | .ok a ts' =>
      let rec go (acc : List α) (stream : TokenStream T) (fuel : Nat) : PResult T (List α) :=
        match fuel with
        | 0 => .ok acc.reverse stream
        | fuel' + 1 =>
          match sep.parse stream with
          | .ok () ts'' =>
            match item.parse ts'' with
            | .ok a' ts''' => go (a' :: acc) ts''' fuel'
            | .err _ _     => .ok acc.reverse stream
          | .err _ _ => .ok acc.reverse stream
      match go [a] ts' ts.tokens.length with
      | .ok as ts'' => .ok as ts''
      | .err msg p  => .err msg p
    | .err _ _ => .ok [] ts

  maxLookahead := max item.maxLookahead sep.maxLookahead
  lookahead_bound := Nat.max_le.mpr ⟨item.lookahead_bound, sep.lookahead_bound⟩

-- choice from a list.
def Parser.choice {T α : Type} {k : Nat} (ps : List (Parser T α k)) : Parser T α k :=
  ps.foldl Parser.orElse (Parser.fail "no alternatives matched")

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // scanner to parser
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- lexer: wraps scanner rules to produce typed tokens.
structure Lexer (T : Type) where
  rules : List (Scanner Bytes × Option T)

-- TODO[b7r6]: !! this is too nested for a language without a formatter !!

-- tokenize entire input using lexer rules (first match wins).
partial def Lexer.tokenizeAll {T : Type} (lex : Lexer T) (bs : Bytes) : List (Token T) :=
  let rec tryRules (rs : List (Scanner Bytes × Option T)) (input : Bytes) (offset : Nat) :
      ScanResult (Option (Token T)) :=
    match rs with
    | [] => ScanResult.notFound
    | (scanner, optType) :: rest =>
      match scanner.scan input with
      | ScanResult.found content remaining =>
        match optType with
        | Option.some t =>
          ScanResult.found (Option.some ⟨t, String.fromUTF8! content, offset⟩) remaining
        | Option.none => ScanResult.found Option.none remaining
      | ScanResult.notFound     => tryRules rest input offset
      | ScanResult.incomplete n => ScanResult.incomplete n

  let rec go (input : Bytes) (offset : Nat) (acc : List (Token T)) : List (Token T) :=
    if input.size == 0 then acc.reverse
    else
      match tryRules lex.rules input offset with
      | ScanResult.found (Option.some tok) rest =>
        go rest (offset + tok.lexeme.length) (tok :: acc)
      | ScanResult.found Option.none rest =>
        go rest (offset + (input.size - rest.size)) acc
      | _ => acc.reverse
  go bs 0 []

-- convert scanner output to parser input.
def Lexer.toStream {T : Type} (lex : Lexer T) (bs : Bytes) : TokenStream T :=
  TokenStream.fromList (lex.tokenizeAll bs)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // grammar analysis
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- FIRST/FOLLOW set types for LL(k) conflict detection.
-- full computation deferred to protocol-specific modules.

structure FirstSet (T : Type) where
  tokens : List T
  hasEpsilon : Bool
  deriving Repr

structure FollowSet (T : Type) where
  tokens : List T
  hasEof : Bool
  deriving Repr

inductive Symbol (T N : Type) where
  | term : T → Symbol T N
  | nonterm : N → Symbol T N
  deriving Repr

structure Rule (T N : Type) where
  lhs : N
  rhs : List (Symbol T N)
  deriving Repr

structure Grammar (T N : Type) where
  rules : List (Rule T N)
  start : N
  deriving Repr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                      // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- TODO[b7r6]: !! write real tests !!

end Continuity.Codec.Core.Parser
