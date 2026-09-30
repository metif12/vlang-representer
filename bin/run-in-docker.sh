#!/usr/bin/env bash

# Synopsis:
# Run the representer against one solution directory, using the Docker image.
#
# Arguments:
# $1: solution directory
# $2: output directory (optional, defaults to a new directory beside the solution)
#
# Example:
# ./bin/run-in-docker.sh tests/example-double-quoted-strings

set -euo pipefail

cd "$(dirname "$0")/.." || exit 1

# See bin/run-tests-in-docker.sh: Git Bash on Windows mangles /solution/, so
# the automatic conversion is disabled and host paths are converted explicitly.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

to_docker_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s' "$1"
    fi
}

image="${IMAGE:-exercism/vlang-representer:dev}"

if [ $# -lt 1 ]; then
    echo "usage: ./bin/run-in-docker.sh <solution-dir> [output-dir]" >&2
    exit 1
fi

solution_dir="$(cd "$1" && pwd)"
slug="$(basename "$solution_dir")"
output_dir="${2:-${solution_dir}/output}"

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

docker build -q -t "$image" . >/dev/null

docker run --rm \
    --network none \
    --mount "type=bind,src=$(to_docker_path "$solution_dir"),dst=/solution,readonly" \
    --mount "type=bind,src=$(to_docker_path "$output_dir"),dst=/output" \
    "$image" "$slug" /solution/ /output/
