import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "As the night came on, Turner found the edge again.

       It seemed like a long time since he’d been there, but when it clicked
       in, it was like he’d never left. It was that superhuman synchromesh
       flow that stimulants only approximated. He could only score for it on
       the site of a major defection, one where he was in command, and then
       only in the final hours before the actual move."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Parser

/-
  Parser — LL(k) grammar-based parsing for structured text.

  The most powerful level in the power hierarchy:

    `Box`     — LL(0) + dep, bidirectional, for binary formats
    `Scanner` — LL(0) + delimiter scan, one-way, for text/line protocols
    `Parser`  — LL(k), token-based, for structured text (JSON, config, DSLs)

  Key properties:
    - Token-based: lexer (`Scanner`) produces tokens, `Parser` consumes them
    - Fixed lookahead k: predictable O(n) performance
    - No backtracking: ordered choice, first match wins
    - Lookahead bound proven: `maxLookahead ≤ k`
    - Determinism by construction: `parse` is a function
-/


end Continuity.Codec.Core.Parser
