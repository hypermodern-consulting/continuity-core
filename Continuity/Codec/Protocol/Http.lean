import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "the breakers rolled in, their edges transparent
      as green glass, and beneath them the tide pulled
      everything toward some invisible destination. Each
      wave carried a method inscribed in its crest — GET,
      POST, the ancient verbs of an older sea — followed
      by a train of headers that described what the wave
      wanted, what it was willing to accept, how long it
      would wait. The shore was nothing but an agreement,
      a status code returned in the undertow, and when
      the wave broke it left behind a body — or nothing
      at all."

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

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                  // core // method and header
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

open Continuity.Codec.Core.Box

inductive Method where
  | get | head | post | put | delete | connect | options | trace | patch
  deriving Repr, DecidableEq

def Method.toString : Method → String
  | .get => "GET" | .head => "HEAD" | .post => "POST" | .put => "PUT"
  | .delete => "DELETE" | .connect => "CONNECT" | .options => "OPTIONS"
  | .trace => "TRACE" | .patch => "PATCH"

structure Header where
  name : String
  value : String
  deriving Repr, DecidableEq

structure RequestLine where
  method : Method
  target : String
  version : String
  deriving Repr

structure StatusLine where
  version : String
  statusCode : Nat
  reasonPhrase : String
  deriving Repr

structure Request where
  requestLine : RequestLine
  headers : List Header
  body : Option Bytes

structure Response where
  statusLine : StatusLine
  headers : List Header
  body : Option Bytes

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                 // parse // request utilities
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def CRLF : Bytes := "\r\n".toUTF8

def parseMethod (s : String) : Option Method :=
  match s with
  | "GET" => some .get | "HEAD" => some .head | "POST" => some .post
  | "PUT" => some .put | "DELETE" => some .delete | "CONNECT" => some .connect
  | "OPTIONS" => some .options | "TRACE" => some .trace | "PATCH" => some .patch
  | _ => none

def findHeader (name : String) (headers : List Header) : Option String :=
  headers.find? (fun h => h.name.toLower == name.toLower) |>.map Header.value

def contentLength (headers : List Header) : Option Nat :=
  findHeader "content-length" headers |>.bind String.toNat?

inductive TransferEncoding where
  | identity | chunked | gzip | deflate | compress
  deriving Repr, DecidableEq

end Continuity.Codec.Protocol.Http
