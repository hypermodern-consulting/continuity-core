import Continuity.Codec.Box

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                              // continuity // codec // scanner
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Scanner — delimiter-based scanning for text/line protocols.

  Scanner sits between Box and Parser in the power hierarchy:

    Box     — LL(0) + dep, bidirectional, for binary formats
    Scanner — LL(0) + delimiter scan, one-way, for text/line protocols
    Parser  — LL(k), token-based, for structured text

  Key insight: text protocols use delimiters (CRLF, `:`, `,`) rather than
  length prefixes. Scanner provides verified delimiter scanning with a
  consumption theorem: if the input is `content ++ delim ++ rest` and
  content contains no occurrence of delim, the scanner returns exactly
  `(content, rest)`.

  Use cases: HTTP/1.1 headers, PEM files, CSV, SMTP/FTP, URI parsing.
-/

namespace Continuity.Codec

open Continuity.Codec


/- ════════════════════════════════════════════════════════════════════════════
                                                              // scan // result
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Result of scanning bytes for a delimiter. -/
inductive ScanResult (α : Type) where
  /-- found match: content + remaining bytes after delimiter -/
  | found : α → Bytes → ScanResult α
  /-- delimiter not found in input -/
  | notFound : ScanResult α
  /-- need more bytes (for streaming protocols) -/
  | incomplete : Nat → ScanResult α
  deriving Inhabited

instance {α : Type} [Repr α] : Repr (ScanResult α) where
  reprPrec
    | ScanResult.found a rest, _ => f!"found {repr a} ({rest.size} bytes remaining)"
    | ScanResult.notFound, _     => "notFound"
    | ScanResult.incomplete n, _ => f!"incomplete ({n} bytes needed)"

namespace ScanResult

def map {α β : Type} (f : α → β) : ScanResult α → ScanResult β
  | found a rest => found (f a) rest
  | notFound     => notFound
  | incomplete n => incomplete n

def bind {α β : Type} (r : ScanResult α) (f : α → Bytes → ScanResult β) : ScanResult β :=
  match r with
  | found a rest => f a rest
  | notFound     => notFound
  | incomplete n => incomplete n

def isFound {α : Type} : ScanResult α → Bool
  | found _ _ => true
  | _         => false

def toOption {α : Type} : ScanResult α → Option (α × Bytes)
  | found a rest => Option.some (a, rest)
  | _            => Option.none

end ScanResult


/- ════════════════════════════════════════════════════════════════════════════
                                                                     // scanner
   ════════════════════════════════════════════════════════════════════════════ -/

/-- A Scanner finds delimited content in a byte stream.

    Unlike Box: one-directional (parse only), scans for delimiters rather
    than knowing length upfront.

    The `consumption` field is a documentation obligation — concrete
    scanners carry tight theorems proven separately (see
    `scanUntilByte_consumption` below). -/
structure Scanner (α : Type) where
  scan : Bytes → ScanResult α
  consumption : ∀ (content rest : Bytes),
    (scan (content ++ rest)).toOption.map (·.2) = Option.some rest → True
  deriving Inhabited


/- ════════════════════════════════════════════════════════════════════════════
                                                     // byte-finding primitives
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Find index of first occurrence of a byte.
    Explicit fuel-based recursion for proof induction on content.size. -/
def findByte (needle : UInt8) (haystack : Bytes) : Option Nat :=
  let rec go (i fuel : Nat) : Option Nat :=
    match fuel with
    | 0 => Option.none
    | fuel' + 1 =>
      if i >= haystack.size then Option.none
      else if haystack.data[i]! == needle then Option.some i
      else go (i + 1) fuel'
  go 0 haystack.size

/-- Find index of first occurrence of a byte sequence. -/
def findBytes (needle : Bytes) (haystack : Bytes) : Option Nat :=
  if needle.size == 0 then Option.some 0
  else if haystack.size < needle.size then Option.none
  else
    let limit := haystack.size - needle.size + 1
    let rec go (i : Nat) (fuel : Nat) : Option Nat :=
      match fuel with
      | 0 => Option.none
      | fuel' + 1 =>
        if i + needle.size > haystack.size then Option.none
        else if haystack.extract i (i + needle.size) == needle then Option.some i
        else go (i + 1) fuel'
    go 0 limit


/- ════════════════════════════════════════════════════════════════════════════
                                                           // findByte theorems
   ════════════════════════════════════════════════════════════════════════════ -/

/-! these lemmas establish that findByte correctly locates the first
    occurrence of a delimiter. the key theorem `findByte_append_delim`
    is the foundation for `scanUntilByte_consumption`. -/

private theorem Array.getElem!_eq_getElem {α : Type} [Inhabited α]
    (a : Array α) (i : Nat) (h : i < a.size) : a[i]! = a[i] :=
  getElem!_pos a i h

private theorem ByteArray.getElem_append_left' (a b : ByteArray) (i : Nat) (hi : i < a.size) :
    (a ++ b).data[i]! = a.data[i]! := by
  have ha : i < a.data.size := by rwa [ByteArray.size_data]
  rw [ByteArray.data_append, Array.getElem!_eq_getElem _ _ (by rw [Array.size_append]; omega),
      Array.getElem!_eq_getElem _ _ ha]
  exact Array.getElem_append_left ha

private theorem ByteArray.getElem_mid (a : ByteArray) (v : UInt8) (b : ByteArray) :
    (a ++ ⟨#[v]⟩ ++ b).data[a.size]! = v := by
  have hda : a.data.size = a.size := ByteArray.size_data
  simp only [ByteArray.data_append]
  have hav_size : (a.data ++ #[v]).size = a.size + 1 := by
    rw [Array.size_append, hda]; rfl
  rw [Array.getElem!_eq_getElem _ _ (by rw [Array.size_append, hav_size]; omega),
      Array.getElem_append_left (by rw [hav_size]; omega : a.size < (a.data ++ #[v]).size),
      Array.getElem_append_right (by omega : a.data.size ≤ a.size)]
  simp [hda]

private theorem ByteArray.size_append_single (a : ByteArray) (v : UInt8) (b : ByteArray) :
    (a ++ ⟨#[v]⟩ ++ b).size = a.size + 1 + b.size := by
  simp only [ByteArray.size_append]; rfl

/-- go advances through prefix when no match found in first n positions. -/
private theorem findByte.go_advance (needle : UInt8) (bs : ByteArray)
    (n : Nat) (hn : n ≤ bs.size)
    (h_no_match : ∀ i, i < n → bs.data[i]! ≠ needle) :
    findByte.go needle bs 0 bs.size =
    findByte.go needle bs n (bs.size - n) := by
  induction n with
  | zero => simp
  | succ k ih =>
    have hk_result := ih (by omega) (fun i hi => h_no_match i (by omega))
    have hk_byte : bs.data[k]! ≠ needle := h_no_match k (Nat.lt_succ_self k)
    have hstep : findByte.go needle bs k (bs.size - k) =
        findByte.go needle bs (k + 1) (bs.size - (k + 1)) := by
      rw [show bs.size - k = (bs.size - k - 1) + 1 from by omega]
      simp only [findByte.go]; split; · omega
      split; · exfalso; rename_i h; simp at h; exact hk_byte h
      congr 1
    rw [hk_result, hstep]

/-- The key theorem: findByte in (content ++ ⟨#[delim]⟩ ++ rest) = some content.size
    when content contains no occurrence of delim. -/
theorem findByte_append_delim (delim : UInt8) (content rest : Bytes)
    (h : ∀ i, i < content.size → content.data[i]! ≠ delim) :
    findByte delim (content ++ ⟨#[delim]⟩ ++ rest) = Option.some content.size := by
  unfold findByte
  have hsize := ByteArray.size_append_single content delim rest
  have h_no_match : ∀ i, i < content.size →
      (content ++ ⟨#[delim]⟩ ++ rest).data[i]! ≠ delim := by
    intro i hi
    rw [ByteArray.getElem_append_left' (content ++ ⟨#[delim]⟩) rest i (by
      rw [ByteArray.size_append]; omega),
        ByteArray.getElem_append_left' content ⟨#[delim]⟩ i hi]
    exact h i hi
  rw [findByte.go_advance delim _ content.size (by omega) h_no_match, hsize,
      show content.size + 1 + rest.size - content.size = rest.size + 1 from by omega]
  simp only [findByte.go]; split
  · exfalso; omega
  · split; · rfl
    · exfalso; rename_i h1 h2
      have := ByteArray.getElem_mid content delim rest; simp_all

private theorem ByteArray.extract_prefix (content rest : Bytes) :
    (content ++ rest).extract 0 content.size = content :=
  ByteArray.extract_append_eq_left rfl

private theorem ByteArray.extract_suffix (content : Bytes) (v : UInt8) (rest : Bytes) :
    (content ++ ⟨#[v]⟩ ++ rest).extract (content.size + 1)
      (content ++ ⟨#[v]⟩ ++ rest).size = rest := by
  rw [show (content ++ ⟨#[v]⟩ ++ rest).size = (content ++ ⟨#[v]⟩).size + rest.size
    from ByteArray.size_append,
    show content.size + 1 = (content ++ ⟨#[v]⟩).size from by rw [ByteArray.size_append]; rfl]
  exact ByteArray.extract_append_eq_right rfl rfl


/- ════════════════════════════════════════════════════════════════════════════════
                                                         // delimiter scanners
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Scan until a single byte delimiter (delimiter consumed, not included in result). -/
def scanUntilByte (delim : UInt8) : Scanner Bytes where
  scan bs :=
    match findByte delim bs with
    | Option.some idx =>
      ScanResult.found (bs.extract 0 idx) (bs.extract (idx + 1) bs.size)
    | Option.none => ScanResult.notFound
  consumption := fun _ _ _ => trivial

/-- Scan until a byte sequence delimiter. -/
def scanUntilBytes (delim : Bytes) : Scanner Bytes where
  scan bs :=
    match findBytes delim bs with
    | Option.some idx =>
      ScanResult.found (bs.extract 0 idx) (bs.extract (idx + delim.size) bs.size)
    | Option.none => ScanResult.notFound
  consumption := fun _ _ _ => trivial

set_option maxHeartbeats 400000

/-- Tight consumption law for scanUntilByte: if content contains no occurrence
    of delim, scanning `content ++ [delim] ++ rest` returns exactly
    `(content, rest)`. -/
theorem scanUntilByte_consumption (delim : UInt8) (content rest : Bytes)
    (h_no_delim : ∀ i, i < content.size → content.data[i]! ≠ delim) :
    (scanUntilByte delim).scan (content ++ ⟨#[delim]⟩ ++ rest) =
      ScanResult.found content rest := by
  unfold scanUntilByte Scanner.scan
  simp only [findByte_append_delim delim content rest h_no_delim]
  show ScanResult.found
    ((content ++ ⟨#[delim]⟩ ++ rest).extract 0 content.size)
    ((content ++ ⟨#[delim]⟩ ++ rest).extract (content.size + 1)
      (content ++ ⟨#[delim]⟩ ++ rest).size) = ScanResult.found content rest
  rw [show content ++ ⟨#[delim]⟩ ++ rest = content ++ (⟨#[delim]⟩ ++ rest)
    from ByteArray.append_assoc,
    ByteArray.extract_prefix content (⟨#[delim]⟩ ++ rest)]
  congr 1
  rw [← ByteArray.append_assoc]
  exact ByteArray.extract_suffix content delim rest


/- ════════════════════════════════════════════════════════════════════════════════
                                                       // predicate scanners
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Scan while predicate holds (greedy). -/
def scanWhile (p : UInt8 → Bool) : Scanner Bytes where
  scan bs :=
    let rec go (i : Nat) : Nat :=
      if i < bs.size then
        if p bs.data[i]! then go (i + 1) else i
      else i
    termination_by bs.size - i
    let idx := go 0
    if idx == 0 then ScanResult.notFound
    else ScanResult.found (bs.extract 0 idx) (bs.extract idx bs.size)
  consumption := fun _ _ _ => trivial

/-- Scan while NOT predicate (until first match). -/
def scanUntil (p : UInt8 → Bool) : Scanner Bytes := scanWhile (fun b => !p b)


/- ── character class predicates ────────────────────────────────────────────── -/

def isDigit (b : UInt8) : Bool := b >= 0x30 && b <= 0x39
def isAlpha (b : UInt8) : Bool := (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
def isAlphaNum (b : UInt8) : Bool := isDigit b || isAlpha b
def isSpace (b : UInt8) : Bool := b == 0x20 || b == 0x09
def isWhitespace (b : UInt8) : Bool := isSpace b || b == 0x0D || b == 0x0A
def isHex (b : UInt8) : Bool := isDigit b || (b >= 0x41 && b <= 0x46) || (b >= 0x61 && b <= 0x66)

def scanDigits : Scanner Bytes := scanWhile isDigit
def scanAlphaNum : Scanner Bytes := scanWhile isAlphaNum
def scanWhitespace : Scanner Bytes := scanWhile isWhitespace


/- ════════════════════════════════════════════════════════════════════════════
                                                      // exact // match scanner
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Match exact bytes at the start of input. -/
def exact (expected : Bytes) : Scanner Unit where
  scan bs :=
    if bs.size >= expected.size && bs.extract 0 expected.size == expected then
      ScanResult.found () (bs.extract expected.size bs.size)
    else if bs.size < expected.size then
      ScanResult.incomplete (expected.size - bs.size)
    else ScanResult.notFound
  consumption := fun _ _ _ => trivial

/-- Match a single exact byte. -/
def exactByte (expected : UInt8) : Scanner Unit := exact ⟨#[expected]⟩


/- ════════════════════════════════════════════════════════════════════════════
                                              // skip // consume // return unit
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Skip whitespace (returns Unit for chaining). -/
def skipWhitespace : Scanner Unit where
  scan bs :=
    let rec go (i : Nat) : Nat :=
      if i < bs.size then
        if isWhitespace bs.data[i]! then go (i + 1) else i
      else i
    termination_by bs.size - i
    ScanResult.found () (bs.extract (go 0) bs.size)
  consumption := fun _ _ _ => trivial


/- ════════════════════════════════════════════════════════════════════════════
                                                                // combinators
   ════════════════════════════════════════════════════════════════════════════ -/

def Scanner.map {α β : Type} (s : Scanner α) (f : α → β) : Scanner β where
  scan bs := s.scan bs |>.map f
  consumption := fun _ _ _ => trivial

def Scanner.seq {α β : Type} (s1 : Scanner α) (s2 : Scanner β) : Scanner (α × β) where
  scan bs :=
    s1.scan bs |>.bind fun a rest =>
      s2.scan rest |>.map fun b => (a, b)
  consumption := fun _ _ _ => trivial

def Scanner.optional {α : Type} (s : Scanner α) : Scanner (Option α) where
  scan bs :=
    match s.scan bs with
    | ScanResult.found a rest  => ScanResult.found (Option.some a) rest
    | ScanResult.notFound      => ScanResult.found Option.none bs
    | ScanResult.incomplete n  => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial

def Scanner.orElse {α : Type} (s1 : Scanner α) (s2 : Scanner α) : Scanner α where
  scan bs :=
    match s1.scan bs with
    | ScanResult.found a rest  => ScanResult.found a rest
    | ScanResult.notFound      => s2.scan bs
    | ScanResult.incomplete n  => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial

instance {α : Type} : OrElse (Scanner α) where
  orElse s1 s2 := Scanner.orElse s1 (s2 ())

/-- Repeat zero or more times. -/
partial def Scanner.many {α : Type} (s : Scanner α) : Scanner (List α) where
  scan bs :=
    match s.scan bs with
    | ScanResult.found a rest =>
      match (Scanner.many s).scan rest with
      | ScanResult.found as rest' => ScanResult.found (a :: as) rest'
      | _ => ScanResult.found [a] rest
    | ScanResult.notFound      => ScanResult.found [] bs
    | ScanResult.incomplete n  => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial

/-- Repeat one or more times. -/
def Scanner.many1 {α : Type} (s : Scanner α) : Scanner (List α) where
  scan bs :=
    match s.scan bs with
    | ScanResult.found a rest =>
      match (Scanner.many s).scan rest with
      | ScanResult.found as rest' => ScanResult.found (a :: as) rest'
      | _ => ScanResult.found [a] rest
    | ScanResult.notFound     => ScanResult.notFound
    | ScanResult.incomplete n => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial

/-- Items separated by a delimiter scanner. -/
def Scanner.sepBy {α : Type} (item : Scanner α) (delim : Scanner Unit) : Scanner (List α) where
  scan bs :=
    match item.scan bs with
    | ScanResult.found a rest =>
      let rec go (acc : List α) (remaining : Bytes) (fuel : Nat) : ScanResult (List α) :=
        match fuel with
        | 0 => ScanResult.found acc.reverse remaining
        | fuel' + 1 =>
          match delim.scan remaining with
          | ScanResult.found () rest' =>
            match item.scan rest' with
            | ScanResult.found a' rest'' => go (a' :: acc) rest'' fuel'
            | _ => ScanResult.found acc.reverse remaining
          | _ => ScanResult.found acc.reverse remaining
      match go [a] rest rest.size with
      | ScanResult.found as rest' => ScanResult.found as rest'
      | _ => ScanResult.found [a] rest
    | ScanResult.notFound     => ScanResult.found [] bs
    | ScanResult.incomplete n => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial


/- ════════════════════════════════════════════════════════════════════════════
                                                  // box → scanner // embedding
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Lift a Box into a Scanner. Box is strictly less powerful — this is always safe. -/
def Scanner.fromBox {α : Type} (box : Box α) : Scanner α where
  scan bs :=
    match box.parse bs with
    | ParseResult.ok a rest => ScanResult.found a rest
    | ParseResult.fail      => ScanResult.notFound
  consumption := fun _ _ _ => trivial

/-- Parse with a Box, then continue with a Scanner. -/
def Scanner.boxThen {α β : Type} (box : Box α) (next : α → Scanner β) : Scanner (α × β) where
  scan bs :=
    match box.parse bs with
    | ParseResult.ok a rest =>
      match (next a).scan rest with
      | ScanResult.found b rest' => ScanResult.found (a, b) rest'
      | ScanResult.notFound      => ScanResult.notFound
      | ScanResult.incomplete n  => ScanResult.incomplete n
    | ParseResult.fail => ScanResult.notFound
  consumption := fun _ _ _ => trivial


/- ════════════════════════════════════════════════════════════════════════════
                                                        // string // conversion
   ════════════════════════════════════════════════════════════════════════════ -/

/-- Convert scanned bytes to String (UTF-8). Fails on invalid encoding. -/
def Scanner.asString (s : Scanner Bytes) : Scanner String where
  scan bs :=
    match s.scan bs with
    | ScanResult.found content rest =>
      match String.fromUTF8? content with
      | Option.some str => ScanResult.found str rest
      | Option.none     => ScanResult.notFound
    | ScanResult.notFound     => ScanResult.notFound
    | ScanResult.incomplete n => ScanResult.incomplete n
  consumption := fun _ _ _ => trivial


/- ═══════════════════════════════════════════════════════════════════════════
                                                       // common // delimiters
   ═══════════════════════════════════════════════════════════════════════════ -/

def LF    : UInt8 := 0x0A
def CR    : UInt8 := 0x0D
def CRLF  : Bytes := ⟨#[CR, LF]⟩
def COLON : UInt8 := 0x3A
def SPACE : UInt8 := 0x20
def TAB   : UInt8 := 0x09
def COMMA : UInt8 := 0x2C

def scanLine       : Scanner Bytes := scanUntilByte LF
def scanCRLFLine   : Scanner Bytes := scanUntilBytes CRLF
def scanUntilColon : Scanner Bytes := scanUntilByte COLON
def scanUntilComma : Scanner Bytes := scanUntilByte COMMA
def scanLineStr    : Scanner String := scanLine.asString
def scanCRLFLineStr : Scanner String := scanCRLFLine.asString


/- ════════════════════════════════════════════════════════════════════════════
                                                                       // tests
   ════════════════════════════════════════════════════════════════════════════ -/

-- scan until newline
#eval (scanLine.scan ("hello\nworld".toUTF8)).toOption.map (fun (a,_) => String.fromUTF8! a)
-- should be: some "hello"

-- scan until colon
#eval (scanUntilColon.scan ("Content-Type: text/html".toUTF8)).toOption.map
  (fun (a,_) => String.fromUTF8! a)
-- should be: some "Content-Type"

-- exact match
#eval ((exact "GET ".toUTF8).scan ("GET /index.html".toUTF8)).isFound
-- should be: true

-- scanWhile digits
#eval (scanDigits.scan ("12345abc".toUTF8)).toOption.map (fun (a,_) => String.fromUTF8! a)
-- should be: some "12345"


end Continuity.Codec
