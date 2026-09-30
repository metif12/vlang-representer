#!/usr/bin/env bash

# Synopsis:
# Test the representer by running it against a predefined set of solutions with
# an expected output.
#
# Output:
# Diffs the expected representation and mapping against the actual ones and
# exits non-zero on the first mismatch.
#
# Example:
# ./bin/run-tests.sh

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

exit_code=0
diff_file="$(mktemp)"
trap 'rm -f "$diff_file"' EXIT

for test_dir in tests/*/; do
    [ -d "$test_dir" ] || continue
    test_dir_name="$(basename "$test_dir")"
    test_dir_path="$(cd "$test_dir" && pwd)"

    expect_error="${test_dir_path}/.expect-error"

    bin/run.sh "$test_dir_name" "$test_dir_path/" "$test_dir_path/" >/dev/null 2>&1
    actual_exit_code=$?

    if [ -f "$expect_error" ]; then
        if [ "$actual_exit_code" -eq 0 ]; then
            echo "FAIL ${test_dir_name}: expected a non-zero exit code"
            exit_code=1
        else
            echo "PASS ${test_dir_name}: failed as expected"
        fi
        continue
    fi

    if [ "$actual_exit_code" -ne 0 ]; then
        echo "FAIL ${test_dir_name}: exited ${actual_exit_code}, expected 0"
        exit_code=1
        continue
    fi

    for pair in \
        "representation.txt:expected_representation.txt" \
        "mapping.json:expected_mapping.json" \
        "representation.json:expected_representation.json"
    do
        actual_file="${test_dir_path}/${pair%%:*}"
        expected_file="${test_dir_path}/${pair##*:}"

        if diff -u "$expected_file" "$actual_file" > "$diff_file" 2>&1; then
            echo "PASS ${test_dir_name}: ${pair%%:*}"
        else
            echo "FAIL ${test_dir_name}: ${pair%%:*} differs"
            cat "$diff_file"
            exit_code=1
        fi
    done

    # The interface spec's hard requirement: two different ways of solving the
    # same exercise must not share a representation. A fixture may name its
    # twin in an `equivalent-to` file; their representations must be identical.
    equivalent_to_file="${test_dir_path}/equivalent-to"
    if [ -f "$equivalent_to_file" ]; then
        other_name="$(tr -d '[:space:]' < "$equivalent_to_file")"
        other_dir="tests/${other_name}"
        if [ ! -d "$other_dir" ]; then
            echo "FAIL ${test_dir_name}: equivalent-to names missing fixture '${other_name}'"
            exit_code=1
        elif diff -q "$test_dir_path/representation.txt" "${other_dir}/representation.txt" >/dev/null 2>&1; then
            echo "PASS ${test_dir_name}: same representation as ${other_name}"
        else
            echo "FAIL ${test_dir_name}: representation differs from ${other_name}, but should match"
            exit_code=1
        fi
    fi
done

exit "$exit_code"
