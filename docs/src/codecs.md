# Codec Layer

The codec layer is 19 files specifying wire formats for 13 protocols.
Each protocol is defined in Lean, proven where possible, and emitted
as C and Haskell via the codegen pipeline.

## The Box Type

The core abstraction is `Box α` — a bidirectional codec with two laws:

```
roundtrip:   parse(serialize(a)) = ok a empty
consumption: parse(serialize(a) ++ extra) = ok a extra
```

Roundtrip says you get the same value back. Consumption says you don't
eat trailing bytes. Together they guarantee the codec is faithful.

## Protocols

| Protocol | File | Key types | Roundtrip proven? |
|----------|------|-----------|-------------------|
| Varint | Varint.lean | `varint : Box UInt64` | ✓ (bv_decide) |
| Nix | Nix.lean | `nixString : Box NixString` | ✓ (via lenPrefixed) |
| Protobuf | Protobuf.lean | `Tag`, `Field`, `zigzag` | zigzag ✓ |
| Git | Git.lean | `ObjectType`, `parseTypeSize` | parse only |
| Git Transport | GitTransport.lean | `PktLine`, `SideBandChannel` | parse only |
| HTTP/1.1 | Http.lean | `Method`, `Header`, `Request` | types only |
| HTTP/2 | Http2.lean | `FrameType`, `FrameHeader`, HPACK | types + roundtrip |
| HTTP/3 | Http3.lean | `parseQuicVarint`, QPACK table | parse only |
| ZMTP | Zmtp.lean | `FrameFlags`, `parseFrame` | flags ✓, determinism ✓ |
| SAML | Saml.lean | `VerifiedAssertion` | wrapping attack prevention ✓ |
| EVM | EVM.lean | `attestCalldata : Box AttestCalldata` | ✓ (via isoBox+seq) |
| JSON | Json.lean | `Value`, `parseValue` | parse only |
| Dhall | Dhall/*.lean | `Tok`, `Expr`, `parse` | parse only |

## SAML Wrapping Attack Prevention

The SAML codec deserves special mention. XML signature wrapping attacks
are the most common vulnerability in SAML implementations. Continuity
prevents them by construction:

```lean
structure VerifiedAssertion where
  issuer : String
  nameId : String
  conditions : Option Bytes
  -- VerifiedAssertion can only be constructed via `verify`
```

The `verify` function checks the cryptographic signature before
producing a `VerifiedAssertion`. The type system enforces that
identity claims are only accessible after verification. There is
no way to construct a `VerifiedAssertion` without passing through
the signature check — it's not a policy, it's a type.

```lean
theorem no_unverified_identity (ua : UnverifiedAssertion) (vf : Bytes → Bytes → Bool)
    (h : vf ua.signedPayload.signedBytes ua.signedPayload.signatureValue = false) :
    verify ua vf = none
```
