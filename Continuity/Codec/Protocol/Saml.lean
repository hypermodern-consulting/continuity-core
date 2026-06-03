import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Saml

/-
  `SAML` assertion scanning with wrapping attack prevention.

  `findElement` locates named elements in XML without an XML
  parser, bounding search in O(n). `verify` is the only path
  from `UnverifiedAssertion` to `VerifiedAssertion`, ensuring
  identity claims can only be extracted from signed bytes.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Saml
