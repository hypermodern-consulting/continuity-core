import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "They were seated around a square white table in a white room on the
       ground floor, behind the junk-clogged storefront. The floor was scuffed
       hospital tile, molded in a nonslip pattern, and the walls broad slabs
       of dingy white plastic concealing dense layers of antibugging circuitry.
       Compared to the storefront, the white room seemed surgically clean.
       Several alloy tripods bristling with sensors and scanning gear stood
       around the table like abstract sculpture."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Json

/-
  A recursive-descent `JSON` parser over raw bytes.

  Implements `rfc 8259`-conformant parsing via position-based
  scanning. no intermediate tokenization — the scanner feeds
  directly from `Bytes` into the `Value` algebra. `null`, `bool`,
  `number`, `str`, `array`, and `object` are mutually recursive
  in the `parseValue` / `where`-block structure.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Json
