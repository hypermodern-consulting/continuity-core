import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Varint

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "He wiped the plane’s banks, dumping Conroy’s programming, what there was
       of it: the approach from California, identification data for the site, a
       flight plan that would have taken them to a strip within three hundred
       kilometers of Bogotá’s urban core..."
                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Protobuf

/-
  `Protocol Buffers` wire format encoding (`proto3`).

  Varint-based field encoding: each field is a `Tag` (field number
  + wire type) followed by a `Value` in the declared wire format.
  `zigzag` encoding maps signed integers into unsigned varints for
  efficient representation. the `Field` codec handles all four
  `WireType` variants: `varint`, `fixed64`, `lengthDelim`, `fixed32`.
-/

open Continuity.Codec.Core.Box Continuity.Codec.Core.Varint



end Continuity.Codec.Protocol.Protobuf
