import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Varint

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "How could she have imagined that it would be possible to live, to move, in
      the unnatural field of Virek’s wealth without suffering distortion? Virek
      had taken her up, in all her misery, and had rotated her through the
      monstrous, invisible stresses of his money, and she had been changed. Of
      course, she thought, of course: It moves around me constantly, watchful
      and invisible, the vast and subtle mechanism of Herr Virek’s
      surveillance."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Http3

/-
  `HTTP/3` framing over `QUIC` transport (`rfc 9114`).

  `QUIC` variable-length integer encoding per `rfc 9000` §16
  and `QPACK` header compression per `rfc 9204`. frames carry
  `HTTP` semantics across `QUIC` streams with stream-level
  multiplexing and connection migration built into the transport.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Http3
