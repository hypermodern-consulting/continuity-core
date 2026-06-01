import Continuity.Codec.Core.Box

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The data had never been intended for human input. It moved beneath
      the surface in packets, in raw bytes stripped of all the comfortable
      conventions that made the world legible to the eye. To read it at
      all was to unlearn language. Every fixed-width field, every length
      prefix, every count of bytes consumed — these were the glyphs of
      a grammar that predated the user and would survive long after.

      She had seen the code behind the code, the bones beneath the skin
      of the matrix. Once you learned to read the raw streams, nothing
      looked the same. The world resolved into its components."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Bytes

/-
  Byte-level codec primitives built on top of `Box`.

    `takeN`        — parse exactly n bytes
    `FixedBytes n` — n-byte value with size proof
    `fixedBytes n` — `Box` for `FixedBytes n`
    `LenPrefixed`  — u64le length + payload
    `lenPrefixed`  — `Box` for `LenPrefixed`

  all fully proven. zero sorry.
-/

open Continuity.Codec.Core.Box

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                     // take n
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // fixed bytes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure FixedBytes (n : Nat) where
  data : ByteArray
  size_eq : data.size = n

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // length-prefixed
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure LenPrefixed where
  data : ByteArray
  bound : data.size < 2 ^ 64

private theorem size_u64_roundtrip (n : Nat) (h : n < 2 ^ 64) :
    (UInt64.ofNat n).toNat = n := by
  simp [UInt64.ofNat, UInt64.toNat]; omega

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // specializations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def bytes32 : Box (FixedBytes 32) := fixedBytes 32
def bytes20 : Box (FixedBytes 20) := fixedBytes 20
def bytes64 : Box (FixedBytes 64) := fixedBytes 64

-- hex representation for bytes
instance : Repr Bytes where
  reprPrec bs _ :=
    let hex := bs.toList.map fun b =>
      let hi := b.toNat / 16
      let lo := b.toNat % 16
      let toHex := fun n => if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n)
      s!"{toHex hi}{toHex lo}"
    Std.Format.text s!"⟨{String.intercalate " " hex}⟩"

end Continuity.Codec.Core.Bytes
