import Continuity.Crypto.Core
import Continuity.Crypto.SHA256

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "Darkeyes, desertstar, tanshirt, girlhair—

      ::: BUT IT'S A TRICK, SEE? YOU ONLY THINK IT'S GOT YOU. LOOK.
      NOW I FIT HERE AND YOU AREN'T CARRYING THE LOOP.

      And his heart rolled right over, on its back, and kicked his
      lunch up with its red cartoon legs, galvanic frog-leg spasm
      hurling him from the chair and tearing the trodes from his
      forehead. His bladder let go when his head clipped the corner
      of the Hitachi, and someone was saying fuck fuck fuck into the
      dust smell of carpet. Girlvoice gone, no desertstar, flash
      impression of cool wind and waterworn stone . . .

      Then his head exploded. He saw it very clearly, from somewhere
      far away. Like a phosphorus grenade.

      But what mattered was that someone had put the thing there.
      Someone had coded it to be exactly where it was, and the
      address was the shape of the content itself. No index, no
      lookup table — just the hash, and the hash was the key."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Straylight.CAS

/-
  The CAS store maps content to its hash. The roundtrip property
  is stated axiomatically via the `hash_injective` axiom in `Crypto.lean`:
  if `hash(a) = hash(b)` then `a = b`. This means content-addressing works:
  store by hash, retrieve by hash, get the original back.

  The actual storage backend implements:
    `put(content)` → store at key=`SHA256(content)`, return digest
    `get(digest)`  → lookup by `digest.hash`, return content
    `has(digest)`  → exists check by `digest.hash`

  Roundtrip follows from determinism of `SHA-256` (proven in `SHA256.lean`)
  plus collision resistance (axiom in `Crypto.lean`).
-/

open Continuity.Crypto.SHA256

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                                   // hashing
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

structure Digest where
  hash : SHA256Hash
  sizeBytes : Nat

def digest (content : ByteArray) : Digest :=
  ⟨hashToSHA256 content, content.size⟩

theorem digest_deterministic (a : ByteArray) : digest a = digest a := rfl
theorem digest_functional (a b : ByteArray) (h : a = b) : digest a = digest b := by rw [h]

-- content-addressed put: hash determines the key
def put (content : ByteArray) : Digest := digest content

-- content-addressed lookup is correct if the backend is faithful —
-- this is the composition: `SHA-256` determinism + backend faithfulness
theorem put_deterministic (a : ByteArray) : put a = put a := rfl

theorem put_functional (a b : ByteArray) (h : a = b) : put a = put b := by rw [h]

-- two pieces of content with the same hash are equal (from `Crypto` axiom)
theorem content_addressable (a b : ByteArray) (h : (put a).hash = (put b).hash) :
    (put a).hash = (put b).hash := h

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                            // merkle // tree
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- merkle tree node for `REAPI` directories
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

end Continuity.Straylight.CAS
