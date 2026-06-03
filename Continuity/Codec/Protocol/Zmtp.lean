import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Bobby climbed down behind him, into the unmistakable signature smell of
       the Sprawl, a rich amalgam of stale subway exhalations, ancient soot,
       and the carcinogenic tang of fresh plastics, all of it shot through with
       the carbon edge of illicit fossil fuels. High overhead, in the reflected
       glare of arc lamps, one of the unfinished Fuller domes shut out two
       thirds of the salmon-pink evening sky, its ragged edge like broken gray
       honeycomb."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Zmtp

/-
  `ZMTP` 3.x: `ZeroMQ` message transport protocol.

  Defines the greeting, frame flags, and frame parsing machinery
  for the `ZMTP` wire format. The parser is deterministic with
  no backtracking — reserved bits in the flag byte trigger an
  immediate reset. Includes concrete security mechanisms for
  `NULL`, `PLAIN`, and `CURVE` authentication.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Zmtp
