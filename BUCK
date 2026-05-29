genrule(
    name = "continuity",
    srcs = glob(["Continuity/**/*.lean", "Continuity.lean", "lakefile.lean", "lean-toolchain"]),
    out = "continuity",
    cmd = "export PATH=/root/.elan/bin:/usr/bin:/bin:$$PATH ELAN_TOOLCHAIN=leanprover/lean4:v4.30.0 && lake --dir=/home/claude/continuity build && cat /home/claude/continuity/.lake/build/bin/continuity > $OUT",
    visibility = ["PUBLIC"],
)
