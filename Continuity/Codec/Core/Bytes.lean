
import Continuity.Codec.Core.Box

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                 // continuity // codec // bytes
                                                                      bytes.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Byte-level codec primitives built on top of Box.

  `takeN`         — parse exactly n bytes
  `FixedBytes n`  — n-byte value with size proof
  `fixedBytes n`  — Box for FixedBytes
  `LenPrefixed`   — u64le length + payload
  `lenPrefixed`   — Box for LenPrefixed

  All fully proven. Zero sorry.
-/

namespace Continuity.Codec.Core.Bytes

open Continuity.Codec.Core.Box


/- ════════════════════════════════════════════════════════════════════════════════
                                                                    // take n
   ════════════════════════════════════════════════════════════════════════════════ -/

def takeN (n : Nat) (bs : Bytes) : ParseResult Bytes :=
  if _ : bs.size ≥ n then .ok (bs.extract 0 n) (bs.extract n bs.size) else .fail

theorem takeN_of_size_eq (data : ByteArray) (n : Nat) (h : data.size = n) :
    takeN n data = ParseResult.ok data ByteArray.empty := by
  subst h; unfold takeN; simp only [Nat.le_refl, ↓reduceDIte]
  congr 1; exact ByteArray.extract_zero_size; simp

theorem takeN_append_of_size_eq (data extra : ByteArray) (n : Nat) (h : data.size = n) :
    takeN n (data ++ extra) = ParseResult.ok data extra := by
  subst h; unfold takeN; simp only [ByteArray.size_append, Nat.le_add_right, ↓reduceDIte]
  congr 1; exact ByteArray.extract_append_eq_left rfl
  exact ByteArray.extract_append_eq_right rfl rfl


/- ════════════════════════════════════════════════════════════════════════════════
                                                               // fixed bytes
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A byte array of exactly n bytes, with proof. -/
structure FixedBytes (n : Nat) where
  data : ByteArray
  size_eq : data.size = n

/-- Box for FixedBytes n: parse exactly n bytes, roundtrip proven. -/
def fixedBytes (n : Nat) : Box (FixedBytes n) where
  parse bs := match takeN n bs with
    | .ok data rest => if h : data.size = n then .ok ⟨data, h⟩ rest else .fail
    | .fail => .fail
  serialize fb := fb.data
  roundtrip fb := by
    rw [takeN_of_size_eq fb.data n fb.size_eq]
    simp only [fb.size_eq, ↓reduceDIte]
  consumption fb extra := by
    rw [takeN_append_of_size_eq fb.data extra n fb.size_eq]
    simp only [fb.size_eq, ↓reduceDIte]


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // length-prefixed
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- A length-prefixed byte array: u64le length followed by payload.
    Bound ensures the length fits in a u64. -/
structure LenPrefixed where
  data : ByteArray
  bound : data.size < 2 ^ 64

private theorem size_u64_roundtrip (n : Nat) (h : n < 2 ^ 64) :
    (UInt64.ofNat n).toNat = n := by
  simp [UInt64.ofNat, UInt64.toNat]; omega

/-- Box for LenPrefixed: u64le length prefix + payload. -/
def lenPrefixed : Box LenPrefixed where
  parse bs :=
    match u64le.parse bs with
    | .ok len rest =>
      match takeN len.toNat rest with
      | .ok data rest2 =>
        if h : data.size < 2 ^ 64 then .ok ⟨data, h⟩ rest2 else .fail
      | .fail => .fail
    | .fail => .fail
  serialize lp := u64le.serialize lp.data.size.toUInt64 ++ lp.data
  roundtrip lp := by
    rw [u64le.consumption]; simp only []
    rw [size_u64_roundtrip lp.data.size lp.bound]
    rw [takeN_of_size_eq lp.data lp.data.size rfl]
    simp only [lp.bound, ↓reduceDIte]
  consumption lp extra := by
    rw [ByteArray.append_assoc, u64le.consumption]; simp only []
    rw [size_u64_roundtrip lp.data.size lp.bound]
    rw [takeN_append_of_size_eq lp.data extra lp.data.size rfl]
    simp only [lp.bound, ↓reduceDIte]


/- ════════════════════════════════════════════════════════════════════════════════
                                                           // specializations
   ════════════════════════════════════════════════════════════════════════════════ -/

def bytes32 : Box (FixedBytes 32) := fixedBytes 32
def bytes20 : Box (FixedBytes 20) := fixedBytes 20
def bytes64 : Box (FixedBytes 64) := fixedBytes 64

/-- Hex representation for Bytes -/
instance : Repr Bytes where
  reprPrec bs _ :=
    let hex := bs.toList.map fun b =>
      let hi := b.toNat / 16
      let lo := b.toNat % 16
      let toHex := fun n => if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n)
      s!"{toHex hi}{toHex lo}"
    Std.Format.text s!"⟨{String.intercalate " " hex}⟩"

end Continuity.Codec.Core.Bytes
