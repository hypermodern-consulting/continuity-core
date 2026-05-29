# Content-Addressable Store

## Overview

The CAS is where NAR archives, REAPI blobs, and derivation outputs converge.
Everything is addressed by SHA-256 digest.

```
Content ──→ SHA256.hash ──→ SHA256Hash ──→ CAS.Digest ──→ store/retrieve
```

## SHA256Hash

A refinement type ensuring the hash is always exactly 32 bytes:

```lean
structure SHA256Hash where
  bytes : ByteArray
  size_eq : bytes.size = 32
```

`hashToSHA256` produces this type with a proof. You can't construct
a `SHA256Hash` from arbitrary bytes without proving they're 32 bytes long.

## Derivation

A derivation is a build recipe. Its hash determines the output store path.

```lean
structure Derivation where
  inputs : List StorePath
  builder : StorePath
  args : List String
  env : List (String × String)
  outputNames : List String
  addressing : AddressingMode
```

`serializeDerivation` is deterministic — same derivation, same bytes, always.
`derivationHash` hashes the serialized form. This is the content address.

## REAPI Mapping

`fromBuildAction` maps a Continuity `Action` to an REAPI `REAction`:

```lean
def fromBuildAction (action : Action) (inputDir : Directory) : REAction :=
  let cmdDigest := digest (serializeCommand cmd)
  let inputDigest := digest (serializeDirectory inputDir)
  { commandDigest := cmdDigest, inputRootDigest := inputDigest }
```

This is the interop point. Any REAPI-compatible remote cache (Bazel,
BuildBarn, NativeLink) can serve as the execution backend.
