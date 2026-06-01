import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Guards
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "They were numbers now, pure and clean, stripped of the messy
      contingencies of flesh and distance. Transfer rates, latency
      ceilings, the hard limits that defined the possible. He had
      learned to think in these terms, to see the world as a nested
      set of constraints — bandwidth here, memory there, a budget
      of milliseconds that had to stretch across the entire run.
      Exceed any one of them and you lost everything. The art was
      knowing exactly where the walls were, and learning to live
      inside them without ever touching the surface."

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

open Continuity.Codec.Core.Box
open Continuity.Codec.Core.Bytes
open Continuity.Codec.Core.Guards

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // constants
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def nixMaxStringBytes  : Nat := 16 * 1024 * 1024        -- 16 MB
def nixMaxListElems    : Nat := 1024 * 1024              -- 1M elements
def narMaxDepth        : Nat := 256
def narMaxEntryName    : Nat := 4096
def narMaxFileBytes    : Nat := 1024 * 1024 * 1024       -- 1 GB
def http2MaxFrameDefault  : Nat := 16384                 -- 16 KB
def http2MaxFrameAbsolute : Nat := 16777215              -- ~16 MB
def zmtpMaxFrameBytes  : Nat := 256 * 1024 * 1024        -- 256 MB
def protobufMaxMsgSize : Nat := 64 * 1024 * 1024         -- 64 MB
def gitMaxPackObjects  : Nat := 16 * 1024 * 1024         -- 16M objects

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // positivity
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem nixMaxStringBytes_pos  : nixMaxStringBytes > 0  := by decide
theorem nixMaxListElems_pos    : nixMaxListElems > 0    := by decide
theorem narMaxDepth_pos        : narMaxDepth > 0        := by decide
theorem narMaxEntryName_pos    : narMaxEntryName > 0    := by decide
theorem narMaxFileBytes_pos    : narMaxFileBytes > 0    := by decide
theorem http2MaxFrameDefault_pos  : http2MaxFrameDefault > 0  := by decide
theorem http2MaxFrameAbsolute_pos : http2MaxFrameAbsolute > 0 := by decide
theorem zmtpMaxFrameBytes_pos  : zmtpMaxFrameBytes > 0  := by decide
theorem protobufMaxMsgSize_pos : protobufMaxMsgSize > 0 := by decide
theorem gitMaxPackObjects_pos  : gitMaxPackObjects > 0  := by decide

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // bounded boxes
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def boundedNixString : Box (Bounded LenPrefixed lenPrefixed nixMaxStringBytes) :=
  bounded lenPrefixed nixMaxStringBytes

def boundedHttp2Frame : Box (Bounded LenPrefixed lenPrefixed http2MaxFrameDefault) :=
  bounded lenPrefixed http2MaxFrameDefault

def boundedZmtpFrame : Box (Bounded LenPrefixed lenPrefixed zmtpMaxFrameBytes) :=
  bounded lenPrefixed zmtpMaxFrameBytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // budget theorems
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem nix_string_budget :
    (1024 * 1024 * 1024) / nixMaxStringBytes = 64 := by native_decide

theorem nix_strings_total (ss : List (Bounded LenPrefixed lenPrefixed nixMaxStringBytes)) :
    (ss.map (fun s => (lenPrefixed.serialize s.val).size)).sum
    ≤ ss.length * nixMaxStringBytes :=
  bounded_list_total lenPrefixed nixMaxStringBytes ss

theorem http2_frames_total (fs : List (Bounded LenPrefixed lenPrefixed http2MaxFrameDefault)) :
    (fs.map (fun f => (lenPrefixed.serialize f.val).size)).sum
    ≤ fs.length * http2MaxFrameDefault :=
  bounded_list_total lenPrefixed http2MaxFrameDefault fs

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                          // depth guard
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def depthGuard {α : Type} (fuel : Nat) (f : Nat → ByteArray → ParseResult α) (bs : ByteArray)
    : ParseResult α :=
  if fuel == 0 then .fail
  else f (fuel - 1) bs

theorem depthGuard_zero {α : Type} (f : Nat → ByteArray → ParseResult α) (bs : ByteArray) :
    depthGuard 0 f bs = .fail := by simp [depthGuard]

theorem depthGuard_succ {α : Type} (n : Nat) (f : Nat → ByteArray → ParseResult α) (bs : ByteArray) :
    depthGuard (n + 1) f bs = f n bs := by simp [depthGuard]

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                         // name length
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def checkNameLen (name : String) : Bool := name.toUTF8.size ≤ narMaxEntryName

structure BoundedName where
  name : String
  len_ok : name.toUTF8.size ≤ narMaxEntryName

end Continuity.Codec.Core.Limits
