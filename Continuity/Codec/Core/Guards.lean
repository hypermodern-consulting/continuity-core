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
    `exhaustion` — all the bytes in a `Box` must be consumed, no shellcode left behind

  Get these right once. Then it won't be a little wrong everywhere.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Core.Guards
