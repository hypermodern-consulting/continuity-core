import Continuity.Codec.Core.Box
import Std.Tactic.BVDecide

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The architecture of the machine was Byzantine in its economy: every
      register doubled as a counter, every arithmetic instruction doubled as
      a branch. The bits moved like water, seven at a time through the
      serpentine shift paths, the high bit of each byte flagging continuation
      until the most significant zero terminated the flow. COUNT ZERO
      INTERRUPT—On receiving an interrupt, decrement the counter to zero.
      Nothing else happened; the world simply stopped."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Varint

open Continuity.Codec.Core.Box

/-
  Varint — Protobuf-style variable-length integer encoding.

  7 bits per byte, MSB = continuation. Max 10 bytes for `UInt64`.
  Fully proven roundtrip. Zero sorry.

  Used by: `Protobuf`, `Git` pack format, `GRPC` framing.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                    // serialize
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem nat_shr7_lt (n : Nat) (h : n ≥ 128) : n >>> 7 < n := by omega

theorem uint64_shr7_lt (v : UInt64) (h : ¬v < 128) : (v >>> 7).toNat < v.toNat := by
  rw [UInt64.toNat_shiftRight]; simp only [UInt64.toNat_ofNat, Nat.reducePow, Nat.reduceMod]
  exact nat_shr7_lt v.toNat (by simp only [UInt64.not_lt] at h; exact h)

-- serialize varint with accumulator (tail bytes appended to acc).
def svc (v : UInt64) (acc : ByteArray) : ByteArray :=
  if h : v < 128 then acc.push v.toUInt8
  else svc (v >>> 7) (acc.push ((v &&& (0x7F : UInt64)) ||| (0x80 : UInt64)).toUInt8)
termination_by v.toNat
decreasing_by exact uint64_shr7_lt v h

def serializeVarint (v : UInt64) : ByteArray := svc v ByteArray.empty

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                  // accumulator
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private theorem pa (bs : ByteArray) (b : UInt8) : bs.push b = bs ++ {data := #[b]} := by
  apply ByteArray.ext; simp

theorem svc_acc (v : UInt64) (acc : ByteArray) : svc v acc = acc ++ svc v ByteArray.empty := by
  rw [svc.eq_1 v acc, svc.eq_1 v ByteArray.empty]; by_cases h : v < 128
  · simp only [h, ↓reduceDIte, pa, ByteArray.empty_append]
  · simp only [h, ↓reduceDIte]
    rw [svc_acc (v>>>7) (acc.push _), svc_acc (v>>>7) (ByteArray.empty.push _)]
    rw [pa acc, pa ByteArray.empty]; simp [ByteArray.append_assoc, ByteArray.empty_append]
termination_by v.toNat
decreasing_by all_goals {
  rw [UInt64.toNat_shiftRight]
  simp only [UInt64.toNat_ofNat, Nat.reducePow, Nat.reduceMod]
  exact nat_shr7_lt _ (by simp only [UInt64.not_lt] at h; exact h)
}

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                        // parse
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- parse varint with accumulator, shift, and fuel (max 10 bytes for `UInt64`).
def pvt (bs : ByteArray) (acc : UInt64) (shift : UInt64) (fuel : Nat) : ParseResult UInt64 :=
  match fuel with
  | 0 => .fail
  | fuel' + 1 =>
    if h : bs.size > 0 then
      let b : UInt8 := bs[0]'(by omega)
      let acc' : UInt64 := acc ||| ((b.toUInt64 &&& 0x7F) <<< shift)
      if b &&& (0x80 : UInt8) == (0 : UInt8) then
        .ok acc' (bs.extract 1 bs.size)
      else pvt (bs.extract 1 bs.size) acc' (shift + 7) fuel'
    else .fail

def parseVarint (bs : ByteArray) : ParseResult UInt64 := pvt bs 0 0 10

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // bitvec // lemmas
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set_option maxRecDepth 8192 in
theorem va (acc v shift : UInt64) (hs : shift < 57) :
    (acc ||| ((v &&& 0x7F) <<< shift)) ||| ((v >>> 7) <<< (shift + 7)) =
    acc ||| (v <<< shift) := by
  apply UInt64.eq_of_toBitVec_eq
  simp only [UInt64.toBitVec_or, UInt64.toBitVec_and, UInt64.toBitVec_shiftLeft,
    UInt64.toBitVec_shiftRight, UInt64.toBitVec_add, UInt64.toBitVec_ofNat]
  bv_decide

theorem mc (v : UInt64) (h : v < 128) :
    (v.toUInt8 &&& (0x80 : UInt8) == (0 : UInt8)) = true := by
  simp only [beq_iff_eq]; apply UInt8.eq_of_toBitVec_eq
  simp only [UInt8.toBitVec_and, UInt8.toBitVec_ofNat, UInt64.toBitVec_toUInt8]; bv_decide

theorem ms (v : UInt64) (h : ¬v < 128) :
    (((v &&& 0x7F) ||| 0x80).toUInt8 &&& (0x80 : UInt8) == (0 : UInt8)) = false := by
  simp only [beq_eq_false_iff_ne, ne_eq]; intro h_eq; have := congrArg UInt8.toBitVec h_eq
  simp only [UInt8.toBitVec_ofNat] at this
  revert this; bv_decide

theorem vr (v : UInt64) (h : v < 128) :
    (v.toUInt8.toUInt64 &&& (0x7F : UInt64)) = v := by
  apply UInt64.eq_of_toBitVec_eq
  simp only [UInt64.toBitVec_and, UInt64.toBitVec_ofNat, UInt8.toBitVec_toUInt64,
    UInt64.toBitVec_toUInt8]
  bv_decide

theorem l7 (v : UInt64) :
    (((v &&& 0x7F) ||| 0x80).toUInt8.toUInt64 &&& (0x7F : UInt64)) = (v &&& 0x7F) := by
  apply UInt64.eq_of_toBitVec_eq
  simp only [UInt64.toBitVec_and, UInt64.toBitVec_or, UInt64.toBitVec_ofNat,
    UInt8.toBitVec_toUInt64, UInt64.toBitVec_toUInt8]
  bv_decide

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // byte array lemmas
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private def mkB (b : UInt8) : ByteArray := ⟨#[b]⟩

private theorem mksz (b : UInt8) : (mkB b).size = 1 := by simp [mkB, ByteArray.size]

private theorem mkp (b : UInt8) (r : ByteArray) : (mkB b ++ r).size > 0 := by
  have := mksz b; have := @ByteArray.size_append (mkB b) r; omega

private theorem mkg (b : UInt8) (r : ByteArray) : (mkB b ++ r)[0]'(mkp b r) = b := by
  rw [ByteArray.getElem_append_left (hlt := by rw [mksz]; omega)]; rfl

private theorem mkt (b : UInt8) (r : ByteArray) :
    (mkB b ++ r).extract 1 (mkB b ++ r).size = r := by
  exact ByteArray.extract_append_eq_right (mksz b) (by
    have := @ByteArray.size_append (mkB b) r; have := mksz b; omega)

private theorem svc_lt (v : UInt64) (h : v < 128) :
    svc v ByteArray.empty = mkB v.toUInt8 := by
  rw [svc.eq_1]; simp only [h, ↓reduceDIte, pa, ByteArray.empty_append, mkB]

private theorem svc_ge (v : UInt64) (h : ¬v < 128) :
    svc v ByteArray.empty = mkB ((v &&& 0x7F) ||| 0x80).toUInt8 ++ svc (v>>>7) ByteArray.empty := by
  rw [svc.eq_1]; simp only [h, ↓reduceDIte]
  rw [svc_acc, pa, ByteArray.empty_append]; rfl

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // bounds //  tracking
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private theorem a7 (s : UInt64) (h : s < 57) : (s+7).toNat = s.toNat + 7 := by
  rw [UInt64.toNat_add, UInt64.toNat_ofNat]
  simp only [Nat.reducePow, Nat.reduceMod]; have : s.toNat < 57 := h; omega

private theorem pow2_7 : (2:Nat)^7 = 128 := by decide

private theorem bslt (v s : UInt64) (hge : ¬v < 128) (hb : v.toNat < 2^(64-s.toNat)) :
    s < 57 := by
  simp only [UInt64.not_lt] at hge; rcases Nat.lt_or_ge s.toNat 57 with h | h
  · exact h
  · exfalso; have : 2^(64-s.toNat) ≤ 2^7 := Nat.pow_le_pow_right (by omega) (by omega)
    have : (2:Nat)^7 = 128 := pow2_7; have : 2^(64-s.toNat) ≤ 128 := by omega
    have : v.toNat ≥ 128 := hge; omega

private theorem brec (v s : UInt64) (hge : ¬v < 128) (hb : v.toNat < 2^(64-s.toNat)) :
    (v>>>7).toNat < 2^(64-(s+7).toNat) := by
  have hs := bslt v s hge hb
  rw [a7 s hs, UInt64.toNat_shiftRight]
  simp only [UInt64.toNat_ofNat, Nat.reducePow, Nat.reduceMod]
  rw [show 64-(s.toNat+7) = 57-s.toNat from by have : s.toNat < 57 := hs; omega]
  rw [show 64-s.toNat = 7+(57-s.toNat) from by have : s.toNat < 57 := hs; omega,
      Nat.pow_add, pow2_7] at hb
  have := Nat.div_lt_of_lt_mul hb; omega

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                              // main // theorem
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- core correctness theorem: `pvt` inverts `svc` for any shift/fuel satisfying
-- the invariant `shift.toNat + 7*fuel ≥ 64` and `fuel ≥ 1`.
theorem pvt_svc (v : UInt64) (tail : ByteArray) (acc shift : UInt64) (fuel : Nat)
    (hfuel : fuel ≥ 1) (hinv : shift.toNat + 7 * fuel ≥ 64)
    (hbound : v.toNat < 2^(64-shift.toNat))
    : pvt (svc v ByteArray.empty ++ tail) acc shift fuel =
      ParseResult.ok (acc ||| (v <<< shift)) tail := by
  by_cases hlt : v < 128
  · rw [svc_lt v hlt]; cases fuel with
    | zero => omega
    | succ n =>
      unfold pvt; simp only [mkp, ↓reduceDIte, mkg, mc v hlt, ↓reduceIte, mkt, vr v hlt]
  · have hs := bslt v shift hlt hbound
    rw [svc_ge v hlt, ByteArray.append_assoc]; cases fuel with
    | zero => omega
    | succ n =>
      unfold pvt
      simp only [mkp, ↓reduceDIte, mkg, ms v hlt, Bool.false_eq_true, ↓reduceIte, mkt, l7]
      have hn : n ≥ 1 := by have : shift.toNat < 57 := hs; omega
      have hinv_rec : (shift+7).toNat + 7 * n ≥ 64 := by
        rw [a7 shift hs]; have : shift.toNat < 57 := hs; omega
      rw [pvt_svc (v>>>7) tail _ (shift+7) n hn hinv_rec (brec v shift hlt hbound)]
      congr 1; exact va acc v shift hs
  termination_by v.toNat
  decreasing_by exact uint64_shr7_lt v hlt

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                    // roundtrip
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem roundtrip (v : UInt64) :
    parseVarint (serializeVarint v) = ParseResult.ok v ByteArray.empty := by
  have := pvt_svc v ByteArray.empty 0 0 10 (by omega)
    (by simp only [UInt64.toNat_ofNat, Nat.reduceMod, Nat.reducePow]; omega)
    (by simp only [UInt64.toNat_ofNat, Nat.reduceMod, Nat.reducePow, Nat.sub_zero]
        exact UInt64.toNat_lt v)
  simp at this; exact this

theorem consumption (v : UInt64) (extra : ByteArray) :
    parseVarint (serializeVarint v ++ extra) = ParseResult.ok v extra := by
  have := pvt_svc v extra 0 0 10 (by omega)
    (by simp only [UInt64.toNat_ofNat, Nat.reduceMod, Nat.reducePow]; omega)
    (by simp only [UInt64.toNat_ofNat, Nat.reduceMod, Nat.reducePow, Nat.sub_zero]
        exact UInt64.toNat_lt v)
  simp at this; exact this

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                          // box
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- the varint `Box`: fully proven bidirectional codec.
def varint : Box UInt64 where
  parse := parseVarint
  serialize := serializeVarint
  roundtrip v := roundtrip v
  consumption v extra := consumption v extra

end Continuity.Codec.Core.Varint
