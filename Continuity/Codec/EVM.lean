import Continuity.Codec.Box
import Continuity.Codec.Bytes

set_option autoImplicit false

namespace Continuity.Codec.EVM

open Continuity.Codec

abbrev Word := FixedBytes 32
def word : Box Word := fixedBytes 32

abbrev Selector := FixedBytes 4
def selector : Box Selector := fixedBytes 4

def encodeUint64 (v : UInt64) : ByteArray :=
  ByteArray.mk (Array.replicate 24 0) ++ u64le.serialize v

structure AttestCalldata where
  sel : Selector
  contentHash : Word
  signerIdentity : Word
  issuedAt : Word
  expiresAt : Word
  vouchChainRoot : Word

private abbrev Packed := Selector × (Word × (Word × (Word × (Word × Word))))

private def packedBox : Box Packed := seq selector (seq word (seq word (seq word (seq word word))))

private def toPacked (a : AttestCalldata) : Packed :=
  (a.sel, (a.contentHash, (a.signerIdentity, (a.issuedAt, (a.expiresAt, a.vouchChainRoot)))))

private def fromPacked (p : Packed) : AttestCalldata :=
  let (s, (ch, (si, (ia, (ea, vcr))))) := p
  ⟨s, ch, si, ia, ea, vcr⟩

def attestCalldata : Box AttestCalldata :=
  isoBox packedBox fromPacked toPacked
    (fun _ => rfl)
    (fun ⟨_, _, _, _, _, _⟩ => rfl)

def ATTEST_CALLDATA_SIZE : Nat := 4 + 5 * 32

end Continuity.Codec.EVM
