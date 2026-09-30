#!/usr/bin/env bash
# Runs the representer against every real example solution in the V track,
# not just the synthetic fixtures. Catches what the fixtures cannot.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

TRACK="${TRACK:-/d/MyProjects/exercism-vlang}"
# Any V works for a smoke test, but to compare against the checked-in expected
# files use the pinned release: V_BIN=/path/to/v V_VERSION=0.5.2 ./bin/sweep-track.sh
V_BIN="${V_BIN:-v}"
export V_BIN V_VERSION

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

total=0
failed=0
slowest=0
slowest_name=''
declare -a FAILED_LIST=()

for exercise_dir in "$TRACK"/exercises/practice/*/; do
    [ -d "$exercise_dir" ] || continue
    slug="$(basename "$exercise_dir")"
    example="${exercise_dir}.meta/example.v"
    [ -f "$example" ] || continue

    total=$((total + 1))
    target="${work}/${slug}"
    mkdir -p "$target/.meta"
    cp "${exercise_dir}.meta/config.json" "$target/.meta/config.json"
    cp "$example" "$target/${slug}.v"

    out="${work}/${slug}-out"
    mkdir -p "$out"

    s=$(date +%s%N)
    if bin/run.sh "$slug" "$target/" "$out/" >"${out}.log" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    e=$(date +%s%N)
    ms=$(( (e - s) / 1000000 ))

    if [ "$ms" -gt "$slowest" ]; then slowest=$ms; slowest_name=$slug; fi

    if [ "$rc" -ne 0 ]; then
        failed=$((failed + 1))
        FAILED_LIST+=("$slug")
        echo "FAIL($rc) $slug"
        sed 's/^/    /' "${out}.log" | head -5
    fi
done

echo
echo "=== real-solution sweep ==="
echo "exercises run : $total"
echo "failures       : $failed"
echo "slowest        : ${slowest} ms (${slowest_name})"
if [ "$failed" -gt 0 ]; then
    echo "failing        : ${FAILED_LIST[*]}"
fi
