import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false
set_option warningAsError false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Marly dreamed of Alain, dusk in a wildflower field, and he cradled her
      head, then caressed and broke her neck. Lay there unmoving but she knew
      what he was doing. He kissed her all over. He took her money and the keys
      to her room. The stars were huge now, fixed above the bright fields, and
      she could still feel his hands on her neck..."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.EVM

/-
  EVM protocol codecs — `AttestCalldata` serialization for on-chain attestations.

  Encodes an attestation as a packed ABI frame: 4-byte selector followed
  by five 32-byte `Word` fields. Uses the `Box` machinery for bidirectional
  codecs with proved roundtrip.

  Layout: `selector (4B) | contentHash (32B) | signerIdentity (32B) |
  issuedAt (32B) | expiresAt (32B) | vouchChainRoot (32B)`.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.EVM
