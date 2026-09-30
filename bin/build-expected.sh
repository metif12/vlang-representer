#!/usr/bin/env bash
# Regenerates tests/*/expected_* from the current representer.
#
# Review the resulting diff before committing: these files are the contract, so
# a change here means students' stored representations are changing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

for test_dir in tests/*/; do
    name="$(basename "$test_dir")"
    path="$(cd "$test_dir" && pwd)"

    if [ -f "$path/.expect-error" ]; then
        if bin/run.sh "$name" "$path/" "$path/" >/dev/null 2>&1; then
            echo "ERROR: $name has .expect-error but run.sh succeeded" >&2
        else
            echo "kept .expect-error: $name"
        fi
        continue
    fi

    rm -f "$path/representation.txt" "$path/mapping.json" "$path/representation.json"
    if ! bin/run.sh "$name" "$path/" "$path/" >/dev/null; then
        echo "ERROR: $name failed" >&2
        continue
    fi
    cp "$path/representation.txt" "$path/expected_representation.txt"
    cp "$path/mapping.json" "$path/expected_mapping.json"
    cp "$path/representation.json" "$path/expected_representation.json"
    echo "regenerated: $name"
done
