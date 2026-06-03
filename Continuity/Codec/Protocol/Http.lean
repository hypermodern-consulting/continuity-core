import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     "The episode seemed to be reaching some sort of climax—an antique BMW
      fuel-cell conversion had just been strafed by servo-piloted miniature
      West German helicopters on the street below Covina Concourse Courts,
      Michele Morgan Magnum was pistol-whipping her treacherous personal
      secretary with a nickel-plated Nambu, and Suslov, who Bobby was coming
      increasingly to identify with, was casually preparing to get his ass out
      of town with a gorgeous female bodyguard who was Japanese but reminded
      Bobby intensely of another one of the dreamgirls on his holoporn
      unit—when someone screamed."

                                                                    — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/
    
namespace Continuity.Codec.Protocol.Http

/-
  The HTTP Protocol (RFC 9110).

  HTTP/1.x message format: request line and status line,
  followed by a sequence of header fields and an optional
  body. Transfer encodings include identity, chunked,
  gzip, deflate, and compress.

  `CRLF` delimits lines; the body length is determined
  by `Content-Length` or `Transfer-Encoding: chunked`.
-/

-- TODO[b7r6]: port from continuity v13

end Continuity.Codec.Protocol.Http
