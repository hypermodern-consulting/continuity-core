import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Guards
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Limits

/-
  Every magic constant in the codebase lives here.
  Every one is connected to a `Bounded` `Box` through `Guards`.
  Every one has an exhaustion theorem.

  Before this file existed, these constants were comments pretending
  to be security. Now they're types.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Core.Limits
