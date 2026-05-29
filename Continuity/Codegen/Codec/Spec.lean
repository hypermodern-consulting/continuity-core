import Continuity.Emit.Cpp.Ast
import Continuity.Emit.Haskell.Ast

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                          // continuity // codegen // codec spec
                                                                      spec.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  CodecSpec — abstract description of a wire format codec.

  This sits between the Lean Box/Parser definitions (which carry proofs)
  and the target-language code (C++/Haskell, which doesn't). The spec
  captures the operational content — types, parse/serialize steps, enum
  tables — without the proof obligations.

  Each protocol gets a CodecModule. Main.lean walks the modules and
  emits C++ and Haskell files.
-/

namespace Continuity.Codegen.Codec

/-- Primitive wire types that map directly to target-language types. -/
inductive WireType where
  | u8 | u16le | u32le | u64le | u16be | u32be | u64be
  | bool64                   -- Nix-style: u64, 0=false
  | varint                   -- protobuf variable-length
  | bytes (n : Nat)          -- fixed-length byte array
  | lenPrefixed              -- u64le length + payload
  | padded (align : Nat)     -- Nix-style: data + zero-pad to alignment
  deriving Repr

/-- Field in a struct definition. -/
structure FieldSpec where
  name : String
  wireType : WireType
  doc : String := ""
  deriving Repr

/-- Enum variant with numeric code. -/
structure EnumVariant where
  name : String
  code : Nat
  doc : String := ""
  deriving Repr

/-- A complete enum type (like WorkerOp, FrameType). -/
structure EnumSpec where
  name : String
  variants : List EnumVariant
  codeType : WireType := .u64le
  doc : String := ""
  deriving Repr

/-- A struct type (like NixString, Frame, PackHeader). -/
structure StructSpec where
  name : String
  fields : List FieldSpec
  doc : String := ""
  deriving Repr

/-- A named constant (like WORKER_MAGIC_1). -/
structure ConstSpec where
  name : String
  wireType : WireType
  value : Nat
  doc : String := ""
  deriving Repr

/-- A complete codec module — one per protocol. -/
structure CodecModule where
  name : String              -- e.g. "Nix", "Protobuf", "Git"
  namespace_ : String        -- e.g. "continuity::nix"
  doc : String := ""
  constants : List ConstSpec := []
  enums : List EnumSpec := []
  structs : List StructSpec := []
  deriving Repr


/- ════════════════════════════════════════════════════════════════════════════════
                                                      // protocol specifications
   ════════════════════════════════════════════════════════════════════════════════ -/

def nixModule : CodecModule where
  name := "Nix"
  namespace_ := "continuity::nix"
  doc := "Nix daemon wire protocol (nix_daemon.ksy)"
  constants := [
    ⟨"WORKER_MAGIC_1", .u64le, 0x6e697863, "Client hello"⟩,
    ⟨"WORKER_MAGIC_2", .u64le, 0x6478696f, "Server hello"⟩,
    ⟨"STDERR_NEXT",    .u64le, 0x6f6c6d67, ""⟩,
    ⟨"STDERR_READ",    .u64le, 0x64617461, ""⟩,
    ⟨"STDERR_WRITE",   .u64le, 0x64617416, ""⟩,
    ⟨"STDERR_LAST",    .u64le, 0x616c7473, ""⟩,
    ⟨"STDERR_ERROR",   .u64le, 0x63787470, ""⟩
  ]
  enums := [
    ⟨"WorkerOp", [
      ⟨"IsValidPath", 1, ""⟩, ⟨"HasSubstitutes", 3, ""⟩, ⟨"QueryPathHash", 4, ""⟩,
      ⟨"QueryReferences", 5, ""⟩, ⟨"QueryReferrers", 6, ""⟩, ⟨"AddToStore", 7, ""⟩,
      ⟨"BuildPaths", 9, ""⟩, ⟨"EnsurePath", 10, ""⟩, ⟨"AddTempRoot", 11, ""⟩,
      ⟨"SetOptions", 19, ""⟩, ⟨"CollectGarbage", 20, ""⟩,
      ⟨"QueryPathInfo", 26, ""⟩, ⟨"NarFromPath", 38, ""⟩,
      ⟨"AddToStoreNar", 39, ""⟩, ⟨"QueryMissing", 40, ""⟩,
      ⟨"BuildPathsWithResults", 46, ""⟩
    ], .u64le, "Daemon operation codes (protocol 1.38)"⟩
  ]
  structs := [
    ⟨"NixString", [⟨"data", .lenPrefixed, "Padded to 8-byte boundary on wire"⟩], ""⟩,
    ⟨"StorePath", [⟨"path", .lenPrefixed, ""⟩], ""⟩,
    ⟨"ClientHello", [⟨"magic", .u64le, ""⟩], ""⟩,
    ⟨"ServerHello", [⟨"magic", .u64le, ""⟩, ⟨"protocolVersion", .u64le, ""⟩], ""⟩
  ]

def protobufModule : CodecModule where
  name := "Protobuf"
  namespace_ := "continuity::protobuf"
  doc := "Protocol Buffers wire format (protobuf.dev/encoding)"
  enums := [
    ⟨"WireType", [
      ⟨"Varint", 0, ""⟩, ⟨"Fixed64", 1, ""⟩, ⟨"LengthDelimited", 2, ""⟩, ⟨"Fixed32", 5, ""⟩
    ], .u8, ""⟩
  ]
  structs := [
    ⟨"Tag", [⟨"fieldNumber", .varint, ""⟩, ⟨"wireType", .u8, ""⟩], ""⟩,
    ⟨"Field", [⟨"tag", .u8, ""⟩, ⟨"value", .lenPrefixed, ""⟩], ""⟩
  ]

def gitModule : CodecModule where
  name := "Git"
  namespace_ := "continuity::git"
  doc := "Git pack format and smart transport"
  constants := [⟨"PACK_SIGNATURE", .u32be, 0x5041434B, "\"PACK\""⟩]
  enums := [
    ⟨"ObjectType", [
      ⟨"Commit", 1, ""⟩, ⟨"Tree", 2, ""⟩, ⟨"Blob", 3, ""⟩, ⟨"Tag", 4, ""⟩,
      ⟨"OfsDelta", 6, ""⟩, ⟨"RefDelta", 7, ""⟩
    ], .u8, ""⟩
  ]
  structs := [
    ⟨"PackHeader", [⟨"version", .u32be, ""⟩, ⟨"objectCount", .u32be, ""⟩], ""⟩,
    ⟨"ObjectId", [⟨"bytes", .bytes 20, "SHA-1"⟩], ""⟩
  ]

def http2Module : CodecModule where
  name := "Http2"
  namespace_ := "continuity::http2"
  doc := "HTTP/2 frame format (RFC 7540)"
  enums := [
    ⟨"FrameType", [
      ⟨"Data", 0, ""⟩, ⟨"Headers", 1, ""⟩, ⟨"Priority", 2, ""⟩,
      ⟨"RstStream", 3, ""⟩, ⟨"Settings", 4, ""⟩, ⟨"PushPromise", 5, ""⟩,
      ⟨"Ping", 6, ""⟩, ⟨"Goaway", 7, ""⟩, ⟨"WindowUpdate", 8, ""⟩,
      ⟨"Continuation", 9, ""⟩
    ], .u8, ""⟩
  ]
  structs := [
    ⟨"FrameHeader", [
      ⟨"length", .u32be, "24-bit"⟩, ⟨"frameType", .u8, ""⟩,
      ⟨"flags", .u8, ""⟩, ⟨"streamId", .u32be, "31-bit"⟩
    ], ""⟩
  ]

def zmtpModule : CodecModule where
  name := "Zmtp"
  namespace_ := "continuity::zmtp"
  doc := "ZMTP 3.x wire format"
  structs := [
    ⟨"Greeting", [
      ⟨"vMajor", .u8, ""⟩, ⟨"vMinor", .u8, ""⟩,
      ⟨"mechanism", .bytes 20, ""⟩, ⟨"asServer", .u8, ""⟩,
      ⟨"filler", .bytes 31, ""⟩
    ], "64 bytes total"⟩,
    ⟨"FrameFlags", [
      ⟨"more", .u8, "bit 0"⟩, ⟨"long_", .u8, "bit 1"⟩, ⟨"command", .u8, "bit 2"⟩
    ], ""⟩
  ]

def evmModule : CodecModule where
  name := "EVM"
  namespace_ := "continuity::evm"
  doc := "EVM ABI encoding for on-chain attestation"
  structs := [
    ⟨"AttestCalldata", [
      ⟨"selector", .bytes 4, "keccak256 prefix"⟩,
      ⟨"contentHash", .bytes 32, ""⟩, ⟨"signerIdentity", .bytes 32, ""⟩,
      ⟨"issuedAt", .bytes 32, "uint64 left-padded"⟩,
      ⟨"expiresAt", .bytes 32, ""⟩, ⟨"vouchChainRoot", .bytes 32, ""⟩
    ], "164 bytes exactly"⟩
  ]

/-- All protocol modules for codegen. -/
def allModules : List CodecModule :=
  [nixModule, protobufModule, gitModule, http2Module, zmtpModule, evmModule]

end Continuity.Codegen.Codec
