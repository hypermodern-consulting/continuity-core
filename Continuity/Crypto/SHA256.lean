set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                 // continuity // crypto // sha256
                                                                      sha256.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  Pure Lean 4 implementation of FIPS 180-4 (SHA-256).
  No FFI. No libraries. Just arithmetic.

  Kernel-distance, not toolchain-distance.
  Collision resistance is the one axiom (Crypto.lean).
-/

namespace Continuity.Crypto.SHA256

-- §1 Word operations (FIPS 180-4 §3.2, §4.1.2)

abbrev Word := UInt32

@[inline] def rotr (n : UInt32) (x : Word) : Word := (x >>> n) ||| (x <<< (32 - n))
@[inline] def shr (n : UInt32) (x : Word) : Word := x >>> n
@[inline] def ch (x y z : Word) : Word := (x &&& y) ^^^ (~~~ x &&& z)
@[inline] def maj (x y z : Word) : Word := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)
@[inline] def bigSigma0 (x : Word) : Word := rotr 2 x ^^^ rotr 13 x ^^^ rotr 22 x
@[inline] def bigSigma1 (x : Word) : Word := rotr 6 x ^^^ rotr 11 x ^^^ rotr 25 x
@[inline] def smallSigma0 (x : Word) : Word := rotr 7 x ^^^ rotr 18 x ^^^ shr 3 x
@[inline] def smallSigma1 (x : Word) : Word := rotr 17 x ^^^ rotr 19 x ^^^ shr 10 x

-- §2 Constants (cube roots of first 64 primes)

def K : Array Word := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

-- §3 Initial hash values (square roots of first 8 primes)

def H0 : Array Word := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

-- §4 Preprocessing

def decodeBE32 (b : Array UInt8) (i : Nat) : Word :=
  let b0 := (b.getD i 0).toUInt32
  let b1 := (b.getD (i+1) 0).toUInt32
  let b2 := (b.getD (i+2) 0).toUInt32
  let b3 := (b.getD (i+3) 0).toUInt32
  (b0 <<< 24) ||| (b1 <<< 16) ||| (b2 <<< 8) ||| b3

def encodeBE32 (w : Word) : Array UInt8 :=
  #[(w >>> 24).toUInt8, (w >>> 16).toUInt8, (w >>> 8).toUInt8, w.toUInt8]

def pad (msg : ByteArray) : ByteArray :=
  let len := msg.size
  let bitLen : UInt64 := (len * 8).toUInt64
  let padded := msg.push 0x80
  let rem := padded.size % 64
  let zeros := if rem ≤ 56 then 56 - rem else 64 - rem + 56
  let padded := padded ++ ByteArray.mk (.replicate zeros 0)
  let padded := padded.push (bitLen >>> 56).toUInt8
  let padded := padded.push (bitLen >>> 48).toUInt8
  let padded := padded.push (bitLen >>> 40).toUInt8
  let padded := padded.push (bitLen >>> 32).toUInt8
  let padded := padded.push (bitLen >>> 24).toUInt8
  let padded := padded.push (bitLen >>> 16).toUInt8
  let padded := padded.push (bitLen >>> 8).toUInt8
  let padded := padded.push bitLen.toUInt8
  padded

-- §5 Message schedule

def messageSchedule (block : Array UInt8) (offset : Nat) : Array Word :=
  let W := (Array.range 16).map fun i => decodeBE32 block (offset + i * 4)
  (List.range 48).foldl (fun (W : Array Word) _ =>
    let t := W.size
    W.push (smallSigma1 (W.getD (t-2) 0) + W.getD (t-7) 0 +
            smallSigma0 (W.getD (t-15) 0) + W.getD (t-16) 0)
  ) W

-- §6 Compression

structure State where

  a : Word
  b : Word
  c : Word
  d : Word
  e : Word
  f : Word
  g : Word
  hh : Word

@[inline] def round (s : State) (kt wt : Word) : State :=
  let t1 := s.hh + bigSigma1 s.e + ch s.e s.f s.g + kt + wt
  let t2 := bigSigma0 s.a + maj s.a s.b s.c
  { a := t1 + t2, b := s.a, c := s.b, d := s.c,
    e := s.d + t1, f := s.e, g := s.f, hh := s.g }

def compress (H : Array Word) (block : Array UInt8) (offset : Nat) : Array Word :=
  let W := messageSchedule block offset
  let s : State := {
    a := H.getD 0 0, b := H.getD 1 0, c := H.getD 2 0, d := H.getD 3 0,
    e := H.getD 4 0, f := H.getD 5 0, g := H.getD 6 0, hh := H.getD 7 0 }
  let s := (List.range 64).foldl (fun s t => round s (K.getD t 0) (W.getD t 0)) s
  #[H.getD 0 0 + s.a, H.getD 1 0 + s.b, H.getD 2 0 + s.c, H.getD 3 0 + s.d,
    H.getD 4 0 + s.e, H.getD 5 0 + s.f, H.getD 6 0 + s.g, H.getD 7 0 + s.hh]

-- §7 Hash computation

def hash (msg : ByteArray) : ByteArray :=
  let padded := pad msg
  let nBlocks := padded.size / 64
  let H := (List.range nBlocks).foldl (fun H i => compress H padded.data (i * 64)) H0
  H.foldl (fun (acc : ByteArray) w => acc ++ ⟨encodeBE32 w⟩) ByteArray.empty

def hashString (s : String) : ByteArray := hash s.toUTF8

-- §8 Hex encoding

private def hexChar (n : UInt8) : Char :=
  if n < 10 then Char.ofNat (n.toNat + 48) else Char.ofNat (n.toNat + 87)

def toHex (bs : ByteArray) : String :=
  String.ofList (bs.foldl (fun acc b => acc ++ [hexChar (b >>> 4), hexChar (b &&& 0x0f)]) [])

def hashHex (msg : ByteArray) : String := toHex (hash msg)
def hashStringHex (s : String) : String := toHex (hashString s)

-- §9 Properties

theorem deterministic (msg : ByteArray) : hash msg = hash msg := rfl
theorem functional (m1 m2 : ByteArray) (h : m1 = m2) : hash m1 = hash m2 := by rw [h]

-- §10 NIST test vectors

def test_abc : String := hashStringHex "abc"
def expected_abc : String := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

def test_empty : String := hashStringHex ""
def expected_empty : String := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

end Continuity.Crypto.SHA256
