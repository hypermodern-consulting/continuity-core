import Continuity.Straylight.CAS
import Continuity.Nix.Derivation
import Continuity.Build.Core.Action
import Continuity.Build.Core.Command

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      "The mythform is usually encountered in one of two modes. One
      mode assumes that the cyberspace matrix is inhabited, or perhaps
      visited, by entities whose characteristics correspond with the
      primary mythform of a 'hidden people.' The other involves no
      such assumption.

      The point is the translation itself. Getting a `Build.Action`
      to look like a `Command` and a `Directory` to hash like a
      Merkle root — that isn't magic. It's deterministic mapping
      across protocol boundaries. The first mode says something lives
      on the other side. The second says it doesn't matter: the map
      is the map, hash the map, and the CAS does the rest."

                                                                     — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Straylight.REAPI

/-
  REAPI (Remote Execution API) mapping.

  Maps Continuity `Build.Action`s to REAPI `Action`s (Bazel remote cache protocol).
  This is the interop layer — Continuity can use any REAPI-compatible cache
  (Bazel, BuildBarn, NativeLink, buildfarm).

  REAPI `Action` = `hash(Command)` + `hash(input root Directory)`.
  The CAS stores blobs. The Action Cache maps Action digests to results.
-/

open Continuity.Straylight.CAS
open Continuity.Nix.Derivation (writeLP writeLPStr writeLPList writeLPStrList)
open Continuity.Build

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // reapi // types
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- `REAPI` `Command`: what to execute.
-- serialized as protobuf → hashed → stored in `CAS`
structure Command where
  arguments : List String
  environmentVariables : List (String × String)
  outputFiles : List String
  outputDirectories : List String
  workingDirectory : String := ""

-- `REAPI` `Directory`: a Merkle tree node.
-- each file is a `(name, digest, isExecutable)` triple.
-- each subdirectory is a `(name, digest)` reference.
structure FileNode where
  name : String
  digest : CAS.Digest
  isExecutable : Bool

structure DirectoryNode where
  name : String
  digest : CAS.Digest

structure Directory where
  files : List FileNode
  directories : List DirectoryNode

-- `REAPI` `Action`: the top-level execution request.
-- `commandDigest + inputRootDigest + timeout`
structure REAction where
  commandDigest : CAS.Digest
  inputRootDigest : CAS.Digest
  timeoutSeconds : Nat := 3600
  doNotCache : Bool := false

-- `REAPI` `ActionResult`: what came back from execution
structure ActionResult where
  outputFiles : List (String × CAS.Digest)
  outputDirectories : List (String × CAS.Digest)
  exitCode : Int
  stdoutDigest : Option CAS.Digest := none
  stderrDigest : Option CAS.Digest := none


--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                        // serialization
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- serialize a command deterministically for hashing
def serializeCommand (cmd : Command) : ByteArray :=
  let buf := ByteArray.empty
  let buf := writeLPStrList buf cmd.arguments

  let buf := writeLPList buf (cmd.environmentVariables.map fun (k, v) =>
    writeLPStr (writeLPStr ByteArray.empty k) v)

  let buf := writeLPStrList buf cmd.outputFiles
  let buf := writeLPStrList buf cmd.outputDirectories

  writeLPStr buf cmd.workingDirectory

-- serialize a `Directory` deterministically for hashing
def serializeDirectory (dir : Directory) : ByteArray :=
  let buf := ByteArray.empty

  let buf := writeLPList buf (dir.files.map fun f =>
    let b := writeLPStr ByteArray.empty f.name
    let b := writeLP b f.digest.hash.bytes
    b ++ ByteArray.mk #[if f.isExecutable then 1 else 0])

  writeLPList buf (dir.directories.map fun d =>
    let b := writeLPStr ByteArray.empty d.name
    writeLP b d.digest.hash.bytes)

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                     // action // mapping
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- map a Continuity `Build.Action` to an `REAPI` `Action`.
-- the `Build.Action` carries the command + dependencies.
-- the `REAPI` `Action` is: `hash(command) + hash(input directory)`.
def fromBuildAction (action : Action) (inputDir : Directory) : REAction :=
  let cmd : Command := {
    arguments := [action.command.program] ++ action.command.args
    environmentVariables := action.command.env
    outputFiles := action.command.args
    outputDirectories := []
    workingDirectory := ""
  }

  let cmdDigest := CAS.digest (serializeCommand cmd)
  let inputDigest := CAS.digest (serializeDirectory inputDir)

  { commandDigest := cmdDigest
    inputRootDigest := inputDigest }

-- map back: extract outputs from an `ActionResult` into store paths
def toOutputPaths (result : ActionResult) : List (String × CAS.Digest) :=
  result.outputFiles ++ result.outputDirectories

--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
---                                                           // properties
--- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- action mapping is deterministic: same inputs → same `REAPI` action
theorem mapping_deterministic (a : Action) (d : Directory) :
    fromBuildAction a d = fromBuildAction a d := rfl

-- command serialization is functional
theorem command_functional (c1 c2 : Command) (h : c1 = c2) :
    serializeCommand c1 = serializeCommand c2 := by rw [h]

end Continuity.Straylight.REAPI
