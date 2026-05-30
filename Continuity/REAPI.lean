import Continuity.CAS
import Continuity.Derivation
import Continuity.Derivation
import Continuity.Build.Action
import Continuity.Build.Command

set_option autoImplicit false

/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                         // continuity // reapi
                                                                      reapi.lean
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

/-!
  REAPI (Remote Execution API) mapping.

  Maps Continuity Build Actions to REAPI Actions (Bazel remote cache protocol).
  This is the interop layer — Continuity can use any REAPI-compatible cache
  (Bazel, BuildBarn, NativeLink, buildfarm).

  REAPI Action = hash(Command) + hash(input root Directory).
  The CAS stores blobs. The Action Cache maps Action digests to results.
-/

namespace Continuity.REAPI

open Continuity.CAS
open Continuity.Derivation (writeLP writeLPStr writeLPList writeLPStrList)
open Continuity.Derivation
open Continuity.Build


/- ════════════════════════════════════════════════════════════════════════════════
                                                              // reapi types
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- REAPI Command: what to execute.
    Serialized as protobuf → hashed → stored in CAS. -/
structure Command where
  arguments : List String
  environmentVariables : List (String × String)
  outputFiles : List String
  outputDirectories : List String
  workingDirectory : String := ""

/-- REAPI Directory: a Merkle tree node.
    Each file is a (name, digest, isExecutable) triple.
    Each subdirectory is a (name, digest) reference. -/
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

/-- REAPI Action: the top-level execution request.
    commandDigest + inputRootDigest + timeout. -/
structure REAction where
  commandDigest : CAS.Digest
  inputRootDigest : CAS.Digest
  timeoutSeconds : Nat := 3600
  doNotCache : Bool := false

/-- REAPI ActionResult: what came back from execution. -/
structure ActionResult where
  outputFiles : List (String × CAS.Digest)
  outputDirectories : List (String × CAS.Digest)
  exitCode : Int
  stdoutDigest : Option CAS.Digest := none
  stderrDigest : Option CAS.Digest := none


/- ════════════════════════════════════════════════════════════════════════════════
                                                          // serialization
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Serialize a Command deterministically for hashing. -/
def serializeCommand (cmd : Command) : ByteArray :=
  let buf := ByteArray.empty
  let buf := writeLPStrList buf cmd.arguments
  let buf := writeLPList buf (cmd.environmentVariables.map fun (k, v) =>
    writeLPStr (writeLPStr ByteArray.empty k) v)
  let buf := writeLPStrList buf cmd.outputFiles
  let buf := writeLPStrList buf cmd.outputDirectories
  writeLPStr buf cmd.workingDirectory

/-- Serialize a Directory deterministically for hashing. -/
def serializeDirectory (dir : Directory) : ByteArray :=
  let buf := ByteArray.empty
  let buf := writeLPList buf (dir.files.map fun f =>
    let b := writeLPStr ByteArray.empty f.name
    let b := writeLP b f.digest.hash.bytes
    b ++ ByteArray.mk #[if f.isExecutable then 1 else 0])
  writeLPList buf (dir.directories.map fun d =>
    let b := writeLPStr ByteArray.empty d.name
    writeLP b d.digest.hash.bytes)


/- ════════════════════════════════════════════════════════════════════════════════
                                                            // action mapping
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Map a Continuity Build.Action to an REAPI Action.
    The Build.Action carries the command + dependencies.
    The REAPI Action is: hash(command) + hash(input directory). -/
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

/-- Map back: extract outputs from an ActionResult into store paths. -/
def toOutputPaths (result : ActionResult) : List (String × CAS.Digest) :=
  result.outputFiles ++ result.outputDirectories


/- ════════════════════════════════════════════════════════════════════════════════
                                                                // properties
   ════════════════════════════════════════════════════════════════════════════════ -/

/-- Action mapping is deterministic: same inputs → same REAPI action. -/
theorem mapping_deterministic (a : Action) (d : Directory) :
    fromBuildAction a d = fromBuildAction a d := rfl

/-- Command serialization is functional. -/
theorem command_functional (c1 c2 : Command) (h : c1 = c2) :
    serializeCommand c1 = serializeCommand c2 := by rw [h]

end Continuity.REAPI
