import Continuity.Codec.Protocol.Nix
import Continuity.Straylight.CAS

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Turner looked at her. She was twenty, four years his junior, and earned
      roughly nine times his annual salary in a given week. She was blonde,
      her hair cropped short for the series role, deeply tanned, and looked as
      if she was illuminated from within by sunlamps. The blue eyes were
      inhumanly perfect optical instruments, grown in vats in Japan. She was
      both actress and camera, her eyes worth several million New Yen, and in
      the hierarchy of Sense/Net stars, she barely rated."

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Nix.NAR

/-
  NAR (Nix ARchive) serialization.

  NAR is the canonical transfer format for Nix store paths.
  It's deterministic — same content, same archive bytes, always.
  This is what makes content addressing work: hash the NAR, get the path.

  Format: a tree of "nix-archive-1" framed `NixString`s.
    "(", "type", "regular", "contents", <data>, ")"
    "(", "type", "directory", "entry", "(", "name", <n>, "node", <recurse>, ")", ... ")"
    "(", "type", "symlink", "target", <target>, ")"
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Nix.NAR
