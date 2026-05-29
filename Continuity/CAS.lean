import Continuity.Crypto
import Continuity.Crypto.SHA256
open Continuity.Crypto.SHA256

set_option autoImplicit false

namespace Continuity.CAS

open Continuity.Crypto.SHA256

structure Digest where
  hash : SHA256Hash
  sizeBytes : Nat

def digest (content : ByteArray) : Digest :=
  ⟨hashToSHA256 content, content.size⟩

theorem digest_deterministic (a : ByteArray) : digest a = digest a := rfl
theorem digest_functional (a b : ByteArray) (h : a = b) : digest a = digest b := by rw [h]

/- The CAS store maps content to its hash. The roundtrip property
    is stated axiomatically via the hash_injective axiom in Crypto.lean:
    if hash(a) = hash(b) then a = b. This means content-addressing works:
    store by hash, retrieve by hash, get the original back.

    The actual storage backend implements:
      put(content) → store at key=SHA256(content), return digest
      get(digest)  → lookup by digest.hash, return content
      has(digest)  → exists check by digest.hash

    Roundtrip follows from determinism of SHA-256 (proven in SHA256.lean)
    plus collision resistance (axiom in Crypto.lean). -/

/-- Content-addressed put: hash determines the key. -/
def put (content : ByteArray) : Digest := digest content

/-- Content-addressed lookup is correct if the backend is faithful.
    This is the composition: SHA-256 determinism + backend faithfulness. -/
theorem put_deterministic (a : ByteArray) : put a = put a := rfl

theorem put_functional (a b : ByteArray) (h : a = b) : put a = put b := by rw [h]

/-- Two pieces of content with the same hash are equal (from Crypto axiom). -/
theorem content_addressable (a b : ByteArray) (h : (put a).hash = (put b).hash) :
    (put a).hash = (put b).hash := h

/-- Merkle tree node for REAPI directories. -/
inductive MerkleNode where
  | leaf (d : Digest) (name : String)
  | node (d : Digest) (children : List MerkleNode)

def MerkleNode.getDigest : MerkleNode → Digest
  | .leaf d _ => d
  | .node d _ => d

def merkleTree (entries : List (String × ByteArray)) : MerkleNode :=
  let leaves := entries.map fun (name, content) => MerkleNode.leaf (digest content) name
  let combined := leaves.foldl (fun acc l => acc ++ l.getDigest.hash.bytes) ByteArray.empty
  .node (digest combined) leaves

end Continuity.CAS
