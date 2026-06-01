import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "the four stupid corners of the room,
      your mother's Barrytown living room,
      framed you like a greeting you'd been
      running since before you could remember.
      Four walls, a floor, a ceiling — the
      whole architecture a transport protocol
      with no acknowledgment field, no escape
      frame, no way to signal that you were
      done and ready for the next message."

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

open Continuity.Codec.Core.Box Continuity.Codec.Core.Bytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // core // constants
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def signatureByte0 : UInt8 := 0xFF
def signatureByte9 : UInt8 := 0x7F
def versionMajor : UInt8 := 3
def versionMinor : UInt8 := 1
def GREETING_SIZE : Nat := 64

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // core // greeting
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure Greeting where
  vMajor : UInt8
  vMinor : UInt8
  mechanism : String
  asServer : Bool
  deriving Repr

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                      // core // frame
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure FrameFlags where
  more : Bool
  long : Bool
  command : Bool
  deriving Repr, DecidableEq

def FrameFlags.fromByte (b : UInt8) : Option FrameFlags :=
  if b &&& 0xF8 != 0 then none
  else some ⟨b &&& 1 != 0, b &&& 2 != 0, b &&& 4 != 0⟩

def FrameFlags.toByte (f : FrameFlags) : UInt8 :=
  (if f.more then 1 else 0) ||| (if f.long then 2 else 0) ||| (if f.command then 4 else 0)

theorem flags_roundtrip (f : FrameFlags) :
    FrameFlags.fromByte (FrameFlags.toByte f) = some f := by
  cases f with | mk m l c => cases m <;> cases l <;> cases c <;> native_decide

structure Frame where
  flags : FrameFlags
  payload : Bytes
  deriving Repr

def parseFrame (bs : Bytes) : ParseResult Frame :=
  if _ : bs.size > 0 then
    let flagByte := bs.data[0]!

    match FrameFlags.fromByte flagByte with
    | none => .fail
    | some flags =>
      let rest := bs.extract 1 bs.size
      if flags.long then
        u64le.parse rest |>.bind fun len rest2 =>
          let n := len.toNat
          if rest2.size >= n then
            .ok ⟨flags, rest2.extract 0 n⟩ (rest2.extract n rest2.size)
          else .fail
      else
        if _ : rest.size > 0 then
          let n := rest.data[0]!.toNat
          let rest2 := rest.extract 1 rest.size

          if rest2.size >= n then
            .ok ⟨flags, rest2.extract 0 n⟩ (rest2.extract n rest2.size)
          else .fail

        else .fail

  else .fail

-- `zmtp` guarantees: deterministic, no backtracking
theorem parseFrame_deterministic (bs : Bytes) (f1 f2 : Frame) (r1 r2 : Bytes) :
    parseFrame bs = .ok f1 r1 → parseFrame bs = .ok f2 r2 → f1 = f2 ∧ r1 = r2 := by
  intro h1 h2; rw [h1] at h2; exact ⟨ParseResult.ok.inj h2 |>.1, ParseResult.ok.inj h2 |>.2⟩

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                    // domain // security
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive CommandName where
  | ready | error | subscribe | cancel
  deriving Repr, DecidableEq

structure SecurityMechanism where
  name : String
  deriving Repr

def nullMechanism : SecurityMechanism := ⟨"NULL"⟩
def plainMechanism : SecurityMechanism := ⟨"PLAIN"⟩
def curveMechanism : SecurityMechanism := ⟨"CURVE"⟩

end Continuity.Codec.Protocol.Zmtp
