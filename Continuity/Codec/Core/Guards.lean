import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Because he had a good agent, he had a good contract. The contract
      specified his parameters with the same precision that a sculptor's
      maquette defines the boundaries of the eventual bronze. Within those
      bounds he moved freely, secure in the knowledge that exceeding them
      would trigger cascading failure — not merely legal default, but the
      collapse of the entire extraction architecture. He had seen men push
      past their contractual limits, had watched the subsystems that kept
      them alive degrade into chaos as the safeguards unraveled one by
      one. No contract, no protection. No boundary, no survival.

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Guards
/-
  Three combinators that belong in the core:

    `expectPad` — consume n bytes, verify a predicate, reject if violated
    `bounded` — wrap a `Box` with a size ceiling, reject oversized inputs
    `exhaustion` — connect bounded to a resource budget (the missing theorem)

  Get these right once. Then it won't be a little wrong everywhere.
-/

open Continuity.Codec.Core.Box
open Continuity.Codec.Core.Bytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                               // expect pad
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- check that the first n bytes of `bs` satisfy a predicate.
def checkPad (p : UInt8 → Bool) (n : Nat) (bs : ByteArray) : Bool :=
  bs.extract 0 n |>.data.all p

-- consume n bytes, verify each satisfies predicate `p`. reject on violation.
def expectPad (p : UInt8 → Bool) (n : Nat) (bs : ByteArray) : ParseResult Unit :=
  if _ : bs.size ≥ n then
    if checkPad p n bs then .ok () (bs.extract n bs.size)
    else .fail
  else .fail

-- construct padding from a fixed byte value.
def mkPad (v : UInt8) (n : Nat) : ByteArray := ByteArray.mk (Array.replicate n v)

theorem mkPad_size (v : UInt8) (n : Nat) : (mkPad v n).size = n := by
  simp [mkPad, ByteArray.size]

theorem expectPad_of_size_eq (p : UInt8 → Bool) (pad : ByteArray) (n : Nat)
    (h_size : pad.size = n) (h_check : checkPad p n pad = true) :
    expectPad p n pad = ParseResult.ok () ByteArray.empty := by
  subst h_size
  simp only [expectPad, Nat.le_refl, ↓reduceDIte, h_check, ite_true]
  congr 1; simp

theorem expectPad_append_of_size_eq (p : UInt8 → Bool) (pad extra : ByteArray) (n : Nat)
    (h_size : pad.size = n) (h_check : checkPad p n (pad ++ extra) = true) :
    expectPad p n (pad ++ extra) = ParseResult.ok () extra := by
  subst h_size
  simp only [expectPad, ByteArray.size_append, Nat.le_add_right, ↓reduceDIte, h_check, ite_true]
  congr 1; exact ByteArray.extract_append_eq_right rfl rfl

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // bounded
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a value whose serialization is within a size bound.
-- the proof obligation `size_ok` is part of the type — you can't construct
-- a `Bounded` without proving the size fits.
structure Bounded (α : Type) (box : Box α) (maxBytes : Nat) where
  val : α
  size_ok : (box.serialize val).size ≤ maxBytes

-- wrap a `Box` with a size ceiling. rejects oversized inputs at parse time.
-- serialize never exceeds `maxBytes` by construction (`size_ok` in the type).
def bounded {α : Type} (box : Box α) (maxBytes : Nat) : Box (Bounded α box maxBytes) where
  parse bs :=
    match box.parse bs with
    | .ok a rest =>
      if h : (box.serialize a).size ≤ maxBytes then
        .ok ⟨a, h⟩ rest
      else .fail
    | .fail => .fail
  serialize b := box.serialize b.val
  roundtrip b := by
    rw [box.roundtrip b.val]
    simp only [b.size_ok, ↓reduceDIte]
  consumption b extra := by
    rw [box.consumption b.val extra]
    simp only [b.size_ok, ↓reduceDIte]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                // exhaustion
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- a bounded value's serialization never exceeds the bound.
theorem bounded_serialize_le {α : Type} (box : Box α) (maxBytes : Nat)
    (b : Bounded α box maxBytes) :
    (box.serialize b.val).size ≤ maxBytes :=
  b.size_ok

-- for a list of bounded values, total serialization ≤ count × bound.
-- this prevents resource exhaustion: n items at most n × maxBytes total.
theorem bounded_list_total {α : Type} (box : Box α) (maxBytes : Nat)
    (bs : List (Bounded α box maxBytes)) :
    (bs.map (fun b => (box.serialize b.val).size)).sum ≤ bs.length * maxBytes := by
  induction bs with
  | nil => simp
  | cons b rest ih =>
    simp only [List.map, List.sum_cons, List.length_cons, Nat.succ_mul]
    rw [Nat.add_comm]
    exact Nat.add_le_add ih b.size_ok

-- corollary: bounded list fits in a memory budget.
-- given budget M and bound maxBytes, at most M / maxBytes items
-- can be parsed before exhaustion.
theorem bounded_list_fits_budget {α : Type} (box : Box α) (maxBytes : Nat) (budget : Nat)
    (bs : List (Bounded α box maxBytes))
    (h_count : bs.length ≤ budget / maxBytes)
    (_h_pos : maxBytes > 0) :
    (bs.map (fun b => (box.serialize b.val).size)).sum ≤ budget := by
  have h1 := bounded_list_total box maxBytes bs
  have h2 : bs.length * maxBytes ≤ (budget / maxBytes) * maxBytes :=
    Nat.mul_le_mul_right maxBytes h_count
  have h3 : (budget / maxBytes) * maxBytes ≤ budget :=
    Nat.div_mul_le_self budget maxBytes
  omega

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // specializations
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `expectZeros`: reject non-zero padding bytes.
abbrev expectZeros (n : Nat) (bs : ByteArray) : ParseResult Unit :=
  expectPad (· == 0) n bs

-- `expectFF`: reject non-0xFF padding bytes.
abbrev expectFF (n : Nat) (bs : ByteArray) : ParseResult Unit :=
  expectPad (· == 0xFF) n bs

-- bounded length-prefixed string with a size ceiling.
def boundedString (maxBytes : Nat) : Box (Bounded LenPrefixed lenPrefixed maxBytes) :=
  bounded lenPrefixed maxBytes

end Continuity.Codec.Core.Guards
