import Continuity.Codec.Core.Box
import Continuity.Codec.Core.Scanner

set_option autoImplicit false

namespace Continuity.Codec.Protocol.Http

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
