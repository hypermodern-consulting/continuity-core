
/- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                                                                   — Count Zero

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ -/

namespace Continuity.Straylight.REAPI

/-
  REAPI (Remote Execution API) mapping.

  Maps Continuity `Build.Action`s to REAPI `Action`s (Bazel remote cache protocol).
  This is the interop layer — Continuity can use any REAPI-compatible cache
  (Bazel, BuildBarn, NativeLink, buildfarm).

  REAPI `Action` = `hash(Command)` + `hash(input root Directory)`.
  The CAS stores blobs. The Action Cache maps Action digests to results.
-/

end Continuity.Straylight.REAPI
