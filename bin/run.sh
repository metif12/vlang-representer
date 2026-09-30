#!/usr/bin/env bash

# Synopsis:
# Run the representer on a solution.
#
# Arguments:
# $1: exercise slug
# $2: absolute path to solution folder (with a trailing slash)
# $3: absolute path to output directory (with a trailing slash)
#
# Output:
# Writes representation.txt, representation.json and mapping.json into the
# output directory, as specified in
# https://exercism.org/docs/building/tooling/representers/interface
#
# Example:
# ./bin/run.sh two-fer /path/to/two-fer/solution/ /path/to/output/

set -uo pipefail

# The V compiler. Deliberately not `v` from $PATH in the Docker image: the
# version is pinned at build time, because the output of `v fmt` *is* the
# representation, and a new V release would silently change the representation
# of every solution already stored on the website.
V_BIN="${V_BIN:-v}"

# Set by the Dockerfile. bin/run.sh refuses to run against a different compiler,
# because that is precisely the failure mode described above.
V_VERSION="${V_VERSION:-}"

if [ -z "${1:-}" ] || [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
    echo "usage: ./bin/run.sh <exercise-slug> <solution-dir/> <output-dir/>" >&2
    exit 1
fi

slug="$1"
input_dir="${2%/}"
output_dir="${3%/}"
meta_config_json_file="${input_dir}/.meta/config.json"
representation_file="${output_dir}/representation.txt"
representation_json_file="${output_dir}/representation.json"
mapping_file="${output_dir}/mapping.json"

mkdir -p "$output_dir"

echo "${slug}: creating representation..."

# ---------------------------------------------------------------------------
# Guard the pinned compiler
# ---------------------------------------------------------------------------
if [ -n "$V_VERSION" ]; then
    actual_version="$("$V_BIN" version 2>/dev/null | tr -d '\r' | awk '{print $2}')"
    if [ "$actual_version" != "$V_VERSION" ]; then
        echo "expected V $V_VERSION, but '$V_BIN' reports '${actual_version:-unknown}'" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Work out which files make up the solution
# ---------------------------------------------------------------------------
# The solution filename cannot be derived from the slug: secret-handshake's
# solution is secret_handshake.v, not secret-handshake.v. So .meta/config.json
# is the source of truth, and globbing is only a fallback.
#
# The two paths below are sorted and de-duplicated so they always agree. They
# otherwise disagree: .meta/config.json lists files in config order, while the
# glob is sorted. Without this, the same solution would get a different
# representation depending on whether jq happens to be installed in the image,
# which would silently split a solution's mentor comments in two.
solution_files=()

if [ -f "$meta_config_json_file" ] && command -v jq >/dev/null 2>&1; then
    while IFS= read -r relative_path; do
        [ -n "$relative_path" ] && solution_files+=("$relative_path")
    done < <(jq -r '.files.solution[]?' "$meta_config_json_file" 2>/dev/null | sort -u)
fi

if [ "${#solution_files[@]}" -eq 0 ]; then
    while IFS= read -r absolute_path; do
        solution_files+=("$(basename "$absolute_path")")
    done < <(find "$input_dir" -maxdepth 1 -type f -name '*.v' -printf '%f\n' | sort -u)
fi

if [ "${#solution_files[@]}" -eq 0 ]; then
    echo "no solution files found in ${input_dir}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Normalize
# ---------------------------------------------------------------------------
# `v fmt` is the whole normalization. It is used precisely because it is
# semantics-preserving: it cannot make two different solutions collide, and it
# cannot fail to represent a valid one. It is also the highest-value
# normalization available for V, since V accepts both "foo" and 'foo' for the
# same string and lets either style stand.
#
# Nothing is stripped afterwards. Removing blank lines, for instance, would
# rewrite multi-line string literals, so solutions holding 'a\n\nb' and 'a\nb'
# would collapse onto one representation.
normalize() {
    local source_file="$1"
    local formatted

    # v fmt exits non-zero and writes nothing to stdout when a file does not
    # parse. Students submit half-finished solutions all the time, so that is
    # not a representer error: fall back to a weaker, still deterministic
    # normalization instead of failing.
    if formatted="$("$V_BIN" fmt "$source_file" 2>/dev/null)" && [ -n "$formatted" ]; then
        printf '%s\n' "$formatted"
        return 0
    fi

    echo "note: 'v fmt' could not parse $(basename "$source_file"); using whitespace-only normalization" >&2
    sed -E -e 's/[[:space:]]+$//' "$source_file"
}

: > "$representation_file"
index=0

for relative_path in "${solution_files[@]}"; do
    source_file="${input_dir}/${relative_path}"

    if [ ! -f "$source_file" ]; then
        echo "could not find solution file '${relative_path}' in ${input_dir}" >&2
        exit 1
    fi

    # Separate multiple files so they cannot run together into one token stream.
    if [ "$index" -gt 0 ]; then
        printf '\n' >> "$representation_file"
    fi

    normalize "$source_file" >> "$representation_file"
    index=$((index + 1))
done

# No identifiers are renamed, so there is nothing to map back.
echo '{}' > "$mapping_file"
printf '{ "version": 1 }\n' > "$representation_json_file"

echo "${slug}: done"
