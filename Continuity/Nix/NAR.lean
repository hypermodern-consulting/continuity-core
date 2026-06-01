import Continuity.Codec.Protocol.Nix
import Continuity.Straylight.CAS

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "the breakers rolled in, their edges transparent as green glass.
      He saw the long curve of the bay, the white of the coral sand,
      the palms hung still against the sky. Nothing moved. There were
      no birds, no voices. Only the reef, repeating itself beneath the
      water, each ridge an echo of the last.

      And the structure was given, not made — the edges already there,
      waiting. The form preceded the seeing. Like a NAR before its
      hash, or a hash before its path: whatever you get back is exactly
      what you put in, bit for bit, down to the pad byte."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

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

open Continuity.Codec.Protocol.Nix
open Continuity.Straylight.CAS

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                             // nar // entries
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- nar entry — the recursive tree structure
inductive Entry where
  | regular (executable : Bool) (contents : ByteArray)
  | directory (entries : List (String × Entry))
  | symlink (target : String)

-- TODO[b7r6]: !! write a proper `Codec` instance for `NixString`
-- framing instead of the hand-rolled buffer manipulation. the
-- current `writeNixStr`/`writeNixBytes` pair does LEB128-prefixed
-- length + padding, which is exactly what `Codec.Protocol.Nix`
-- already defines !!

-- write a padded `NixString` to buffer
private def writeNixStr (_ : ByteArray) (s : String) : ByteArray :=
  let data := s.toUTF8

  let len := data.size
  let padLen := padSize len

  let lenBytes := ByteArray.mk #[
    (len % 256).toUInt8, ((len / 256) % 256).toUInt8,
    ((len / 65536) % 256).toUInt8, ((len / 16777216) % 256).toUInt8,
    0, 0, 0, 0]

  lenBytes ++ data ++ ByteArray.mk (Array.replicate padLen 0)

private def writeNixBytes (buf : ByteArray) (data : ByteArray) : ByteArray :=
  let len := data.size
  let padLen := padSize len

  let lenBytes := ByteArray.mk #[
    (len % 256).toUInt8, ((len / 256) % 256).toUInt8,
    ((len / 65536) % 256).toUInt8, ((len / 16777216) % 256).toUInt8,
    0, 0, 0, 0]

  buf ++ lenBytes ++ data ++ ByteArray.mk (Array.replicate padLen 0)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                       // serialization
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- serialize a nar entry to bytes
partial def serialize (entry : Entry) : ByteArray :=
  let str := writeNixStr ByteArray.empty

  match entry with
  | .regular exec contents =>
    let buf := str "("
    let buf := buf ++ str "type"
    let buf := buf ++ str "regular"
    let buf := if exec then buf ++ str "executable" ++ str "" else buf
    let buf := buf ++ str "contents"
    let buf := writeNixBytes buf contents
    buf ++ str ")"
  | .directory entries =>
    let buf := str "("
    let buf := buf ++ str "type"
    let buf := buf ++ str "directory"
    let buf := entries.foldl (fun buf (name, child) =>
      let buf := buf ++ str "entry"
      let buf := buf ++ str "("
      let buf := buf ++ str "name"
      let buf := buf ++ str name
      let buf := buf ++ str "node"
      let buf := buf ++ serialize child
      buf ++ str ")"
    ) buf
    buf ++ str ")"
  | .symlink target =>
    let buf := str "("
    let buf := buf ++ str "type"
    let buf := buf ++ str "symlink"
    let buf := buf ++ str "target"
    let buf := buf ++ str target
    buf ++ str ")"

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // nar // hashing
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- serialize a complete nar archive (with magic header)
def serializeNAR (entry : Entry) : ByteArray :=
  let str := writeNixStr ByteArray.empty
  str NAR_MAGIC ++ serialize entry

-- hash a nar archive to get its content digest
def narDigest (entry : Entry) : Digest :=
  digest (serializeNAR entry)

-- nar serialization is deterministic
theorem nar_deterministic (e : Entry) : serializeNAR e = serializeNAR e := rfl

end Continuity.Nix.NAR
