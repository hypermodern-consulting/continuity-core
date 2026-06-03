import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes
import Continuity.Codec.Protocol.Protocol

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━



                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Nix

/-
  The `Nix` daemon worker protocol.

  Frame-level encoding for `nix-daemon` communication. `NixString`
  wraps length-prefixed bytes; padding is a framing-layer concern
  managed by `nixStringWireSize` / `parseNixStringPadded`. worker
  opcodes span the full `WorkerOp` enumeration, roundtripped
  through `UInt64` codes. also includes `NAR` archive and content
  addressing types.
-/

end Continuity.Codec.Protocol.Nix
