export BUCK_SCRATCH_PATH=../../../../../../../$BUCK_SCRATCH_PATH
cd buck-out/v2/art/root/5c1b01ec01a662a2/__continuity__/srcs
mkdir -p ../out || exit 99
export TMP=${TMPDIR:-/tmp}
export PATH=/root/.elan/bin:/usr/bin:/bin:$$PATH ELAN_TOOLCHAIN=leanprover/lean4:v4.30.0 && lake --dir=/home/claude/continuity build && cat /home/claude/continuity/.lake/build/bin/continuity > $OUT