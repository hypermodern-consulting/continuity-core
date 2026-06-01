import Std.Tactic.BVDecide

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The intimacy of the thing was hideous. Cornell had sealed those
      objects in their glass-fronted boxes, fragments of a disordered
      world made suddenly legible only through the narrow frame that
      held them together. A box is a promise, the sort of promise that
      gets kept at the hardware level: what you put in is what you get
      out. The codec does not interpret — it preserves. Every byte
      accounted for, every transformation invertible, the original
      waiting behind the glass like a specimen in formalin."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Box

/-
  The Box: a verified bidirectional codec.

  A `Box α` is the strongest statement continuity makes about a wire
  format. it can serialize an `α` to bytes, parse bytes back to an `α`,
  and the roundtrip is proven correct for all values and all trailing bytes.
  this is the most important file in the project.

  Power hierarchy (most → least obligation):
    `Box`     — bidirectional + roundtrip proof
    `Parser`  — parse only, no serialize, no proof
    `Scanner` — find boundaries only, no value construction
  use the least powerful tool that gets the job done.

  Two laws:
    `roundtrip`  :  parse (serialize a) = ok a empty
    `consumption`:  parse (serialize a ++ extra) = ok a extra
  `consumption` is the stronger property — it subsumes `roundtrip`
  (set extra = empty). we carry both because `roundtrip` is the readable
  one and `consumption` is what makes `seq` composable.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // parse // result
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

abbrev Bytes := ByteArray

inductive ParseResult (α : Type) where
  | ok : α → Bytes → ParseResult α
  | fail : ParseResult α
  deriving DecidableEq

namespace ParseResult

def map {α β : Type} (f : α → β) : ParseResult α → ParseResult β
  | ok a rest => ok (f a) rest
  | fail => fail

def bind {α β : Type} (r : ParseResult α) (f : α → Bytes → ParseResult β) : ParseResult β :=
  match r with
  | ok a rest => f a rest
  | fail => fail

-- simplify lemmas — these fire inside tactic proofs so seq/isoBox go through
@[simp] theorem map_ok {α β : Type} (f : α → β) (a : α) (rest : Bytes) :
    map f (ok a rest) = ok (f a) rest := rfl

@[simp] theorem map_fail {α β : Type} (f : α → β) :
    map f (fail : ParseResult α) = fail := rfl

@[simp] theorem bind_ok {α β : Type} (a : α) (rest : Bytes) (f : α → Bytes → ParseResult β) :
    bind (ok a rest) f = f a rest := rfl

@[simp] theorem bind_fail {α β : Type} (f : α → Bytes → ParseResult β) :
    bind (fail : ParseResult α) f = fail := rfl

end ParseResult

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                         // box
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a Box is a verified bidirectional codec.
--   `roundtrip`:   parse (serialize a) = ok a empty
--   `consumption`: parse (serialize a ++ extra) = ok a extra
-- the `extra` parameter in `consumption` is what makes boxes compose.
-- when you sequence two boxes, the first one consumes exactly its bytes
-- and leaves the rest for the second one. without `consumption`, you'd
-- know the right value comes back but not that the right number of bytes
-- are consumed. n.b. "Box" is from Joseph Cornell's boxes.
structure Box (α : Type) where
  parse : Bytes → ParseResult α
  serialize : α → Bytes
  roundtrip : ∀ a, parse (serialize a) = ParseResult.ok a ByteArray.empty
  consumption : ∀ a extra, parse (serialize a ++ extra) = ParseResult.ok a extra


--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // primitive // boxes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- the unit box: zero bytes, always succeeds. identity element for `seq`.
def unit : Box Unit where
  parse bs := .ok () bs
  serialize _ := ByteArray.empty
  roundtrip := by intro a; rfl
  consumption := by intro a extra; simp [ByteArray.empty_append]


-- u8 helpers

private def parseU8 (bs : Bytes) : ParseResult UInt8 :=
  if h : bs.size > 0 then
    .ok bs[0] (bs.extract 1 bs.size)
  else
    .fail

private def serializeU8 (v : UInt8) : Bytes :=
  [v].toByteArray

private theorem singleton_size (v : UInt8) : [v].toByteArray.size = 1 := by simp

-- single byte box with verified roundtrip.
def u8 : Box UInt8 where
  parse := parseU8
  serialize := serializeU8

  roundtrip := by
    intro v
    simp only [parseU8, serializeU8]
    have hsize : [v].toByteArray.size > 0 := by simp
    simp only [hsize, ↓reduceDIte]
    have hval : [v].toByteArray[0]'hsize = v := by simp
    have hrest : [v].toByteArray.extract 1 [v].toByteArray.size = ByteArray.empty := by simp
    simp only [hval, hrest]

  consumption := by
    intro v extra
    simp only [parseU8, serializeU8]
    have hsize : ([v].toByteArray ++ extra).size > 0 := by
      simp [ByteArray.size_append, List.size_toByteArray]; omega
    simp only [hsize, ↓reduceDIte]
    have hval : ([v].toByteArray ++ extra)[0]'hsize = v := by
      have h0 : (0 : Nat) < [v].toByteArray.size := by simp
      rw [ByteArray.getElem_append_left h0]; simp
    have hrest : ([v].toByteArray ++ extra).extract 1 ([v].toByteArray ++ extra).size = extra := by
      rw [ByteArray.extract_append_eq_right (by simp : 1 = [v].toByteArray.size)
          (by simp [ByteArray.size_append] : ([v].toByteArray ++ extra).size =
              [v].toByteArray.size + extra.size)]
    simp only [hval, hrest]


-- u64le

private def extractByte64 (v : BitVec 64) (i : Nat) (_ : i < 8 := by omega) : BitVec 8 :=
  (v >>> (i * 8)).setWidth 8

private def combineBytes64 (b0 b1 b2 b3 b4 b5 b6 b7 : BitVec 8) : BitVec 64 :=
  b0.setWidth 64 |||
  (b1.setWidth 64 <<< 8) |||
  (b2.setWidth 64 <<< 16) |||
  (b3.setWidth 64 <<< 24) |||
  (b4.setWidth 64 <<< 32) |||
  (b5.setWidth 64 <<< 40) |||
  (b6.setWidth 64 <<< 48) |||
  (b7.setWidth 64 <<< 56)

private def parseU64le (bs : Bytes) : ParseResult (BitVec 64) :=
  if h : bs.size ≥ 8 then
    let b0 := BitVec.ofNat 8 bs[0].toNat
    let b1 := BitVec.ofNat 8 bs[1].toNat
    let b2 := BitVec.ofNat 8 bs[2].toNat
    let b3 := BitVec.ofNat 8 bs[3].toNat
    let b4 := BitVec.ofNat 8 bs[4].toNat
    let b5 := BitVec.ofNat 8 bs[5].toNat
    let b6 := BitVec.ofNat 8 bs[6].toNat
    let b7 := BitVec.ofNat 8 bs[7].toNat
    .ok (combineBytes64 b0 b1 b2 b3 b4 b5 b6 b7) (bs.extract 8 bs.size)
  else .fail

private def serializeU64le (v : BitVec 64) : Bytes :=
  [ (extractByte64 v 0).toNat.toUInt8
  , (extractByte64 v 1).toNat.toUInt8
  , (extractByte64 v 2).toNat.toUInt8
  , (extractByte64 v 3).toNat.toUInt8
  , (extractByte64 v 4).toNat.toUInt8
  , (extractByte64 v 5).toNat.toUInt8
  , (extractByte64 v 6).toNat.toUInt8
  , (extractByte64 v 7).toNat.toUInt8 ].toByteArray

-- the fundamental theorem: combine ∘ extract = id. bv_decide handles it.
private theorem extractBytes64_combineBytes (v : BitVec 64) :
    combineBytes64 (extractByte64 v 0) (extractByte64 v 1) (extractByte64 v 2) (extractByte64 v 3)
                   (extractByte64 v 4) (extractByte64 v 5) (extractByte64 v 6) (extractByte64 v 7) = v := by
  simp only [extractByte64, combineBytes64]; bv_decide

-- UInt8 ↔ BitVec 8 roundtrip lemma
private theorem extractByte_uint8_roundtrip (b : BitVec 8) :
    BitVec.ofNat 8 (b.toNat.toUInt8.toNat) = b := by
  apply BitVec.eq_of_toNat_eq
  simp only [BitVec.toNat_ofNat]
  have hlt : b.toNat < 256 := b.isLt
  have h1 : b.toNat.toUInt8.toNat = b.toNat := by
    unfold Nat.toUInt8 UInt8.ofNat UInt8.toNat
    simp only [BitVec.toNat_ofNat, Nat.mod_eq_of_lt hlt]
  rw [h1]; exact Nat.mod_eq_of_lt hlt

-- per-index simp lemmas: serialize then re-read gives extractByte
private theorem serializeU64le_getElem (v : BitVec 64) (i : Nat) (hi : i < 8) :
    (serializeU64le v)[i]'(by simp [serializeU64le, List.size_toByteArray]; exact hi) =
    (extractByte64 v i hi).toNat.toUInt8 := by
  simp only [serializeU64le]
  match i with | 0 => simp | 1 => simp | 2 => simp | 3 => simp
               | 4 => simp | 5 => simp | 6 => simp | 7 => simp

-- combined: BitVec.ofNat 8 (serialize v)[i].toNat = extractByte64 v i
-- per-index @[simp] lemmas — verbose but proven to work with simp

@[simp] private theorem sU64_bv0 (v : BitVec 64) (h : 0 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[0].toNat = extractByte64 v 0 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv1 (v : BitVec 64) (h : 1 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[1].toNat = extractByte64 v 1 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv2 (v : BitVec 64) (h : 2 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[2].toNat = extractByte64 v 2 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv3 (v : BitVec 64) (h : 3 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[3].toNat = extractByte64 v 3 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv4 (v : BitVec 64) (h : 4 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[4].toNat = extractByte64 v 4 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv5 (v : BitVec 64) (h : 5 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[5].toNat = extractByte64 v 5 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv6 (v : BitVec 64) (h : 6 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[6].toNat = extractByte64 v 6 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU64_bv7 (v : BitVec 64) (h : 7 < (serializeU64le v).size := by simp) :
    BitVec.ofNat 8 (serializeU64le v)[7].toNat = extractByte64 v 7 := by
  rw [serializeU64le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem serializeU64le_size (v : BitVec 64) :
    (serializeU64le v).size = 8 := by simp [serializeU64le, List.size_toByteArray]

-- main roundtrip theorem
private theorem parseU64le_roundtrip (v : BitVec 64) :
    parseU64le (serializeU64le v) = ParseResult.ok v ByteArray.empty := by
  simp only [parseU64le]
  have hsize : (serializeU64le v).size ≥ 8 := by simp
  simp only [hsize, ↓reduceDIte]
  have hextract : (serializeU64le v).extract 8 (serializeU64le v).size = ByteArray.empty := by simp
  simp only [hextract]; congr 1
  simp only [sU64_bv0, sU64_bv1, sU64_bv2, sU64_bv3,
             sU64_bv4, sU64_bv5, sU64_bv6, sU64_bv7]
  exact extractBytes64_combineBytes v

-- consumption theorem
private theorem parseU64le_consumption (v : BitVec 64) (extra : Bytes) :
    parseU64le (serializeU64le v ++ extra) = ParseResult.ok v extra := by
  simp only [parseU64le]
  have hsize : (serializeU64le v ++ extra).size ≥ 8 := by
    simp [ByteArray.size_append]
  simp only [hsize, ↓reduceDIte]
  have hextract : (serializeU64le v ++ extra).extract 8 (serializeU64le v ++ extra).size = extra := by
    rw [ByteArray.extract_append_eq_right (by simp : 8 = (serializeU64le v).size)
        (by simp [ByteArray.size_append])]
  simp only [hextract]; congr 1
  have h0 : (0:Nat) < (serializeU64le v).size := by simp
  have h1 : (1:Nat) < (serializeU64le v).size := by simp
  have h2 : (2:Nat) < (serializeU64le v).size := by simp
  have h3 : (3:Nat) < (serializeU64le v).size := by simp
  have h4 : (4:Nat) < (serializeU64le v).size := by simp
  have h5 : (5:Nat) < (serializeU64le v).size := by simp
  have h6 : (6:Nat) < (serializeU64le v).size := by simp
  have h7 : (7:Nat) < (serializeU64le v).size := by simp
  simp only [ByteArray.getElem_append_left h0, ByteArray.getElem_append_left h1,
             ByteArray.getElem_append_left h2, ByteArray.getElem_append_left h3,
             ByteArray.getElem_append_left h4, ByteArray.getElem_append_left h5,
             ByteArray.getElem_append_left h6, ByteArray.getElem_append_left h7]
  simp only [sU64_bv0, sU64_bv1, sU64_bv2, sU64_bv3,
             sU64_bv4, sU64_bv5, sU64_bv6, sU64_bv7]
  exact extractBytes64_combineBytes v

-- 64-bit little-endian box (BitVec 64). fully verified.
def u64leBitVec : Box (BitVec 64) where
  parse := parseU64le
  serialize := serializeU64le
  roundtrip := parseU64le_roundtrip
  consumption := parseU64le_consumption

-- u32le (same pattern, 4 bytes)

private def extractByte32 (v : BitVec 32) (i : Nat) (_ : i < 4 := by omega) : BitVec 8 :=
  (v >>> (i * 8)).setWidth 8

private def combineBytes32 (b0 b1 b2 b3 : BitVec 8) : BitVec 32 :=
  b0.setWidth 32 |||
  (b1.setWidth 32 <<< 8) |||
  (b2.setWidth 32 <<< 16) |||
  (b3.setWidth 32 <<< 24)

private def parseU32le (bs : Bytes) : ParseResult (BitVec 32) :=
  if h : bs.size ≥ 4 then
    let b0 := BitVec.ofNat 8 bs[0].toNat
    let b1 := BitVec.ofNat 8 bs[1].toNat
    let b2 := BitVec.ofNat 8 bs[2].toNat
    let b3 := BitVec.ofNat 8 bs[3].toNat
    .ok (combineBytes32 b0 b1 b2 b3) (bs.extract 4 bs.size)
  else .fail

private def serializeU32le (v : BitVec 32) : Bytes :=
  [ (extractByte32 v 0).toNat.toUInt8
  , (extractByte32 v 1).toNat.toUInt8
  , (extractByte32 v 2).toNat.toUInt8
  , (extractByte32 v 3).toNat.toUInt8 ].toByteArray

private theorem extractBytes32_combineBytes (v : BitVec 32) :
    combineBytes32 (extractByte32 v 0) (extractByte32 v 1)
                   (extractByte32 v 2) (extractByte32 v 3) = v := by
  simp only [extractByte32, combineBytes32]; bv_decide

@[simp] private theorem serializeU32le_size (v : BitVec 32) :
    (serializeU32le v).size = 4 := by simp [serializeU32le, List.size_toByteArray]

private theorem serializeU32le_getElem (v : BitVec 32) (i : Nat) (hi : i < 4) :
    (serializeU32le v)[i]'(by simp [serializeU32le, List.size_toByteArray]; exact hi) =
    (extractByte32 v i hi).toNat.toUInt8 := by
  simp only [serializeU32le]
  match i with | 0 => simp | 1 => simp | 2 => simp | 3 => simp

@[simp] private theorem sU32_bv0 (v : BitVec 32) (h : 0 < (serializeU32le v).size := by simp) :
    BitVec.ofNat 8 (serializeU32le v)[0].toNat = extractByte32 v 0 := by
  rw [serializeU32le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU32_bv1 (v : BitVec 32) (h : 1 < (serializeU32le v).size := by simp) :
    BitVec.ofNat 8 (serializeU32le v)[1].toNat = extractByte32 v 1 := by
  rw [serializeU32le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU32_bv2 (v : BitVec 32) (h : 2 < (serializeU32le v).size := by simp) :
    BitVec.ofNat 8 (serializeU32le v)[2].toNat = extractByte32 v 2 := by
  rw [serializeU32le_getElem]; exact extractByte_uint8_roundtrip _

@[simp] private theorem sU32_bv3 (v : BitVec 32) (h : 3 < (serializeU32le v).size := by simp) :
    BitVec.ofNat 8 (serializeU32le v)[3].toNat = extractByte32 v 3 := by
  rw [serializeU32le_getElem]; exact extractByte_uint8_roundtrip _

private theorem parseU32le_roundtrip (v : BitVec 32) :
    parseU32le (serializeU32le v) = ParseResult.ok v ByteArray.empty := by
  simp only [parseU32le]
  have hsize : (serializeU32le v).size ≥ 4 := by simp
  simp only [hsize, ↓reduceDIte]
  have hextract : (serializeU32le v).extract 4 (serializeU32le v).size = ByteArray.empty := by simp
  simp only [hextract]; congr 1
  simp only [sU32_bv0, sU32_bv1,
             sU32_bv2, sU32_bv3]
  exact extractBytes32_combineBytes v

private theorem parseU32le_consumption (v : BitVec 32) (extra : Bytes) :
    parseU32le (serializeU32le v ++ extra) = ParseResult.ok v extra := by
  simp only [parseU32le]
  have hsize : (serializeU32le v ++ extra).size ≥ 4 := by simp [ByteArray.size_append]
  simp only [hsize, ↓reduceDIte]
  have hextract : (serializeU32le v ++ extra).extract 4 (serializeU32le v ++ extra).size = extra := by
    rw [ByteArray.extract_append_eq_right (by simp : 4 = (serializeU32le v).size)
        (by simp [ByteArray.size_append])]
  simp only [hextract]; congr 1
  have h0 : (0:Nat) < (serializeU32le v).size := by simp
  have h1 : (1:Nat) < (serializeU32le v).size := by simp
  have h2 : (2:Nat) < (serializeU32le v).size := by simp
  have h3 : (3:Nat) < (serializeU32le v).size := by simp
  simp only [ByteArray.getElem_append_left h0, ByteArray.getElem_append_left h1,
             ByteArray.getElem_append_left h2, ByteArray.getElem_append_left h3]
  simp only [sU32_bv0, sU32_bv1,
             sU32_bv2, sU32_bv3]
  exact extractBytes32_combineBytes v

-- 32-bit little-endian box (BitVec 32). fully verified.
def u32leBitVec : Box (BitVec 32) where
  parse := parseU32le
  serialize := serializeU32le
  roundtrip := parseU32le_roundtrip
  consumption := parseU32le_consumption

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // combinators
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- sequence two boxes. parse A then B, serialize A then B.
-- if both have verified roundtrip, so does the pair.
-- this is where `consumption` earns its keep: we need to know
-- that parseA consumes exactly serialize-A-many bytes and leaves
-- the serialize-B bytes for parseB.

def seq {α β : Type} (boxA : Box α) (boxB : Box β) : Box (α × β) where
  parse bs :=
    boxA.parse bs |>.bind fun a rest =>
      boxB.parse rest |>.map fun b => (a, b)

  serialize ab := boxA.serialize ab.1 ++ boxB.serialize ab.2

  roundtrip := by
    intro ⟨a, b⟩
    simp only [ParseResult.bind, ParseResult.map]
    rw [boxA.consumption a (boxB.serialize b)]
    simp only []
    rw [boxB.roundtrip b]

  consumption := by
    intro ⟨a, b⟩ extra
    simp only [ParseResult.bind, ParseResult.map]
    rw [ByteArray.append_assoc]
    rw [boxA.consumption a (boxB.serialize b ++ extra)]
    simp only []
    rw [boxB.consumption b extra]

-- map a box through an isomorphism. given `Box α` and bijection `f/g`,
-- get `Box β`. this is how you go from `Box (BitVec 64)` to `Box UInt64`.
def isoBox {α β : Type} (box : Box α) (f : α → β) (g : β → α)
    (fg : ∀ b, f (g b) = b) (_gf : ∀ a, g (f a) = a) : Box β where

  parse bs := box.parse bs |>.map f
  serialize b := box.serialize (g b)

  roundtrip := by
    intro b
    show ParseResult.map f (box.parse (box.serialize (g b))) = ParseResult.ok b ByteArray.empty
    rw [box.roundtrip (g b)]; simp [fg]

  consumption := by
    intro b extra
    show ParseResult.map f (box.parse (box.serialize (g b) ++ extra)) = ParseResult.ok b extra
    rw [box.consumption (g b) extra]; simp [fg]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // multi-byte boxes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- u32le and u64le use `BitVec` for clean proofs via `bv_decide`.
-- the key insight: `extractByte` and `combineBytes` are inverses,
-- and `bv_decide` can verify this automatically for fixed widths.

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // derived // boxes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `UInt64` little-endian, via `isoBox` from `BitVec 64`
def u64le : Box UInt64 :=
  isoBox u64leBitVec UInt64.ofBitVec UInt64.toBitVec (fun _ => rfl) (fun _ => rfl)

-- `UInt32` little-endian, via `isoBox` from `BitVec 32`
def u32le : Box UInt32 :=
  isoBox u32leBitVec UInt32.ofBitVec UInt32.toBitVec (fun _ => rfl) (fun _ => rfl)

-- boolean as u64 (Nix wire style): 0 = false, nonzero = true
def bool64 : Box Bool where
  parse bs := (u64le.parse bs).map (· != 0)
  serialize b := u64le.serialize (if b then 1 else 0)
  roundtrip b := by
    simp only [u64le, isoBox, ParseResult.map]
    cases b <;> rw [u64leBitVec.roundtrip] <;> rfl
  consumption b extra := by
    simp only [u64le, isoBox, ParseResult.map]
    cases b <;> rw [u64leBitVec.consumption] <;> rfl

-- two bytes
def u8pair : Box (UInt8 × UInt8) := seq u8 u8

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // parse // result ops
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def ParseResult.isOk {α : Type} : ParseResult α → Bool
  | .ok _ _ => true
  | .fail => false

def ParseResult.toOption {α : Type} : ParseResult α → Option (α × Bytes)
  | .ok a rest => Option.some (a, rest)
  | .fail => Option.none

instance {α : Type} [Repr α] : Repr (ParseResult α) where
  reprPrec
    | .ok a rest, _ => f!"ok {repr a} ({rest.size} bytes remaining)"
    | .fail, _      => "fail"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                        // tests
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- unit
-- #eval unit.serialize ()
-- #eval unit.parse (ByteArray.mk #[0x42])

-- u8
-- #eval u8.serialize (0x42 : UInt8)
-- #eval u8.parse (ByteArray.mk #[0x42, 0xFF])
-- #eval u8.parse (ByteArray.mk #[])

-- u8 roundtrip
-- #eval u8.parse (u8.serialize (0xAB : UInt8) ++ ByteArray.mk #[0x01, 0x02])

-- seq
-- #eval u8pair.parse (ByteArray.mk #[0xAA, 0xBB, 0xCC])

end Continuity.Codec.Core.Box
