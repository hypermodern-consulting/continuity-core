import Std.Tactic.BVDecide

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The intimacy of the thing was hideous. Cornell had sealed those
      objects in their glass-fronted boxes, fragments of a disordered
      world made suddenly legible only through the narrow frame that
      held them together. A box is a promise, the sort of promise that
      gets kept at the hardware level: what you put in is what you get
      out. The codec does not interpret — it preserves. Every byte
      accounted for, every transformation invertible, the original
      waiting behind the glass like a specimen in formalin."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Box

/-
  The Box: a verified bidirectional codec.

  A `Box α` is the strongest statement continuity makes about a wire
  format. it can serialize an `α` to bytes, parse bytes back to an `α`,
  and the roundtrip is proven correct for all values and all trailing bytes.
  this is the most important file in the project.

  Power hierarchy (most → least obligation):
    `Box`     — bidirectional + roundtrip proof
    `Parser`  — parse only, no serialize, no proof
    `Scanner` — find boundaries only, no value construction
  use the least powerful tool that gets the job done.

  Two laws:
    `roundtrip`  :  parse (serialize a) = ok a empty
    `consumption`:  parse (serialize a ++ extra) = ok a extra
  `consumption` is the stronger property — it subsumes `roundtrip`
  (set extra = empty). we carry both because `roundtrip` is the readable
  one and `consumption` is what makes `seq` composable.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Core.Box
