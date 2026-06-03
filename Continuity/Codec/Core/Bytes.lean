import Continuity.Codec.Core.Box

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He hunched his way carefully along the length of each table, tapping
      each console, each black box, lightly as he went. There was a heavily
      modified military side-band transceiver rigged for squirt transmission.
      This would be their link in case Ramirez and Jaylene flubbed the data
      transfer. The squirts were prerecorded, elaborate technical fictions
      encoded by Hosaka’s cryptographers. The content of a given squirt was
      meaningless, but the sequence in which they were broadcast would convey
      simple messages. Sequence B/C/A would inform Hosaka of Mitchell’s
      arrival; F/D would indicate his departure from the site, while F/G
      would signal his death and the concurrent closure of the operation."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Bytes

/-
  Byte-level codec primitives built on top of `Box`.

    `takeN`        — parse exactly n bytes
    `FixedBytes n` — n-byte value with size proof
    `fixedBytes n` — `Box` for `FixedBytes n`
    `LenPrefixed`  — u64le length + payload
    `lenPrefixed`  — `Box` for `LenPrefixed`
    
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Core.Bytes
