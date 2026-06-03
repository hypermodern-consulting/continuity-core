import Continuity.Codec.Core.Box
import Std.Tactic.BVDecide

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The interior of the JAL toroid was so bland, so unremarkable, so utterly
       like any crowded airport, that she felt like laughing. There was the same
       scent of perfume, human tension, and heavily conditioned air, and the same
       background hum of conversation. The point-eight gravity would have made it
       easier to carry a suitcase, but she only had her black purse. Now she took
       her tickets from one of its zippered inner pockets and checked the number
       of her connecting shuttle against the columns of numbers arrayed on the
       nearest wall screen."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Varint

open Continuity.Codec.Core.Box

/-
  Varint — Protobuf-style variable-length integer encoding.
  7 bits per byte, MSB = continuation. Max 10 bytes for `UInt64`.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Core.Varint
