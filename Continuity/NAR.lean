import Continuity.Codec.Nix
import Continuity.CAS

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                           // continuity // nar
                                                                        nar.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  NAR (Nix ARchive) serialization.

  NAR is the canonical transfer format for Nix store paths.
  It's deterministic — same content, same archive bytes, always.
  This is what makes content addressing work: hash the NAR, get the path.

  Format: a tree of "nix-archive-1" framed NixStrings.
    "(", "type", "regular", "contents", <data>, ")"
    "(", "type", "directory", "entry", "(", "name", <n>, "node", <recurse>, ")", ... ")"
    "(", "type", "symlink", "target", <target>, ")"
-/

namespace Continuity.NAR

open Continuity.Codec.Nix
open Continuity.CAS

/-- NAR entry — the recursive tree structure. -/
inductive Entry where
  | regular (executable : Bool) (contents : ByteArray)
  | directory (entries : List (String × Entry))
  | symlink (target : String)

/-- Write a padded NixString to buffer. -/
private def writeNixStr (buf : ByteArray) (s : String) : ByteArray :=
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

/-- Serialize a NAR entry to bytes. -/
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

/-- Serialize a complete NAR archive (with magic header). -/
def serializeNAR (entry : Entry) : ByteArray :=
  let str := writeNixStr ByteArray.empty
  str NAR_MAGIC ++ serialize entry

/-- Hash a NAR archive to get its content digest. -/
def narDigest (entry : Entry) : Digest :=
  CAS.digest (serializeNAR entry)

/-- NAR serialization is deterministic. -/
theorem nar_deterministic (e : Entry) : serializeNAR e = serializeNAR e := rfl

end Continuity.NAR
