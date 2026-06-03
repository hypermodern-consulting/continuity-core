import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Liquid flowers of milky white blossomed from the floor of the tank;
      Bobby, craning forward, saw that they seemed to consist of thousands of
      tiny spheres or bubbles, and then they aligned perfectly with the cubical
      grid and coalesced, forming a top-heavy, asymmetrical structure, a thing
      like a rectilinear mushroom. The surfaces, facets, were white, perfectly
      blank."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Protocol.Git
/-
  The Git Pack Format.

  A binary protocol for storing objects in a compressed,
  self-contained archive. Packs use deltified representation:
  objects reference prior objects via offset or hash, with
  the full graph reconstructed on inflation by `Zlib`.

  Targets `git pack-objects` and `git index-pack` wire format:
    `.pack` — compressed object data with trailing checksum
    `.idx`  — fanout table mapping object ids to pack offsets
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Git
