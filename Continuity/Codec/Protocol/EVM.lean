import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The knob was ridiculous, handmade, baleful; it was there to welcome
      him back to Mexico. But the real interface was elsewhere — in the
      word-sized slots the hardware offered up, thirty-two bytes apiece,
      chained into attestation frames with a selector leading the pack.
      Four bytes for dispatch, then the content hash, then the signer
      identity, then timestamps bracketing the valid window, and finally
      the vouch chain root anchoring the whole assembly to the state tree."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.EVM

open Continuity.Codec.Core.Box Continuity.Codec.Core.Bytes

/-
  EVM protocol codecs — `AttestCalldata` serialization for on-chain attestations.

  Encodes an attestation as a packed ABI frame: 4-byte selector followed
  by five 32-byte `Word` fields. Uses the `Box` machinery for bidirectional
  codecs with proved roundtrip.

  Layout: `selector (4B) | contentHash (32B) | signerIdentity (32B) |
  issuedAt (32B) | expiresAt (32B) | vouchChainRoot (32B)`.
-/

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                    // primitives
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

abbrev Word := FixedBytes 32
def word : Box Word := fixedBytes 32

abbrev Selector := FixedBytes 4
def selector : Box Selector := fixedBytes 4

def encodeUint64 (v : UInt64) : ByteArray :=
  ByteArray.mk (Array.replicate 24 0) ++ u64le.serialize v

def decodeUint64 (bs : ByteArray) : Option UInt64 :=
  if bs.size = 32 then
    let suffix := bs.extract 24 32
    match u64le.parse suffix with
    | .ok v rest => if rest.size = 0 then some v else none
    | .fail => none
  else none

theorem uint64_roundtrip (n : UInt64) : decodeUint64 (encodeUint64 n) = some n := by
  -- TODO[b7r6]: !! proof needed !! -- zero-pad + u64le roundtrip
  sorry

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // attest //  calldata
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure AttestCalldata where
  sel : Selector
  contentHash : Word
  signerIdentity : Word
  issuedAt : Word
  expiresAt : Word
  vouchChainRoot : Word

private abbrev Packed := Selector × (Word × (Word × (Word × (Word × Word))))

private def packedBox : Box Packed := seq selector (seq word (seq word (seq word (seq word word))))

-- flatten `AttestCalldata` to nested tuple for `Box` composition
private def toPacked (a : AttestCalldata) : Packed :=
  (a.sel, (a.contentHash, (a.signerIdentity, (a.issuedAt, (a.expiresAt, a.vouchChainRoot)))))

-- reconstruct `AttestCalldata` from nested tuple
private def fromPacked (p : Packed) : AttestCalldata :=
  let (s, (ch, (si, (ia, (ea, vcr))))) := p
  ⟨s, ch, si, ia, ea, vcr⟩

def attestCalldata : Box AttestCalldata :=
  isoBox packedBox fromPacked toPacked
    (fun _ => rfl)
    (fun ⟨_, _, _, _, _, _⟩ => rfl)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // constants
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def ATTEST_CALLDATA_SIZE : Nat := 4 + 5 * 32

end Continuity.Codec.Protocol.EVM
