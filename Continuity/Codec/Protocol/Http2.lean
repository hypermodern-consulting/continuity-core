import Continuity.Codec.Core.Box

set_option autoImplicit false
set_option warningAsError false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "What he did want now, and very badly, was food. He touched his credit
      chip through the denim of his jeans. He’d go across the street and get a
      sandwich... Then he remembered why he was here, and suddenly it didn’t
      seem very smart to use his chip. If he’d been sussed, after his
      attempted run, they’d have his chip number by now; using it would
      spotlight him for anyone tracking him in cyberspace, pick him out in the
      Barrytown grid like a highway flare in a dark football stadium."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Http2

/-
  The HTTP/2 Protocol (RFC 7540, RFC 7541).

  Multiplexed binary framing layer with header compression
  via `HPACK`. Each frame carries a type, stream identifier,
  and flags; settings are exchanged during connection preface.
  The `HPACK` static table pre-defines 61 header name/value
  pairs; integer encoding uses variable-length prefix
  representation from RFC 7541 §5.1.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Http2
