import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Bytes

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "They moved with the relaxed precision of good technicians,
      scanning the dataflow for the characteristic signatures they
      had been trained to recognize. A ripple in the lattice, a
      brief hesitation in the pulse-train — these were the tokens
      of intrusion, and they had learned to read them as surely as
      a tracker reads the shape of a broken twig. The system was
      vast, but it was legible. Everything that moved through it
      left a trace, and every trace had a shape. You just had to
      know what you were looking for."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Codec.Core.Scanner
/-
  Scanner — delimiter-based scanning for text/line protocols.

  Scanner sits between `Box` and `Parser` in the power hierarchy:

    `Box`     — LL(0) + dep, bidirectional, for binary formats
    `Scanner` — LL(0) + delimiter scan, one-way, for text/line protocols
    `Parser`  — LL(k), token-based, for structured text

  Key insight: text protocols use delimiters (CRLF, `:`, `,`) rather than
  length prefixes. Scanner provides verified delimiter scanning with a
  consumption theorem: if the input is `content ++ delim ++ rest` and
  content contains no occurrence of delim, the scanner returns exactly
  `(content, rest)`.

  Use cases: HTTP/1.1 headers, PEM files, CSV, SMTP/FTP, URI parsing.
-/



end Continuity.Codec.Core.Scanner
