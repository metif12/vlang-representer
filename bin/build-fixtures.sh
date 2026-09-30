#!/usr/bin/env bash
# Generates the test fixtures. Kept as a script so the exact bytes matter
# (tabs vs spaces, trailing whitespace) are visible and reproducible.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

for d in tests/*/; do rm -rf "$d"; done

# --- example-leap: an ordinary, already-formatted solution -----------------
mkdir -p tests/example-leap/.meta
cat > tests/example-leap/.meta/config.json <<'JSON'
{
  "files": {
    "solution": [
      "leap.v"
    ]
  }
}
JSON
printf 'module main\n\n// is_leap_year reports whether a year is a leap year.\nfn is_leap_year(year int) bool {\n\treturn if year %% 100 == 0 { year %% 400 == 0 } else { year %% 4 == 0 }\n}\n' \
    > tests/example-leap/leap.v

# --- the pair that proves string quotes are normalized ---------------------
# The same code, semantically identical: "double" vs 'single' literals, 4 spaces
# vs tabs. These must collapse onto one representation -- this is the single
# highest-value normalization for V, and the reason a representer is worth
# having here at all.
mkdir -p tests/example-double-quoted/.meta
cat > tests/example-double-quoted/.meta/config.json <<'JSON'
{
  "files": {
    "solution": [
      "hello-world.v"
    ]
  }
}
JSON
printf 'module main\n\nfn hello() string {\n    return "Hello, World!"\n}\n' \
    > tests/example-double-quoted/hello-world.v
echo "example-single-quoted" > tests/example-double-quoted/equivalent-to

mkdir -p tests/example-single-quoted/.meta
cp tests/example-double-quoted/.meta/config.json tests/example-single-quoted/.meta/config.json
printf "module main\n\nfn hello() string {\n\treturn 'Hello, World!'\n}\n" \
    > tests/example-single-quoted/hello-world.v

# --- the same, plus a rune literal ---------------------------------------
mkdir -p tests/example-string-with-quote/.meta
cp tests/example-double-quoted/.meta/config.json tests/example-string-with-quote/.meta/config.json
# Same result, written with a double-quoted literal and a rune: the double
# quotes here cannot be switched to single quotes, because the string contains
# one. A normalizer that rewrote quotes blindly would corrupt this.
printf 'module main\n\nfn hello() string {\n    return "Hello, World!"\n}\n\nfn first_letter() u8 {\n    return `H`\n}\n' \
    > tests/example-string-with-quote/hello-world.v

# --- multiple solution files ---------------------------------------------
mkdir -p tests/example-multiple-files/.meta
cat > tests/example-multiple-files/.meta/config.json <<'JSON'
{
  "files": {
    "solution": [
      "years.v",
      "rules.v"
    ]
  }
}
JSON
printf 'module main\n\nfn is_leap_year(year int) bool {\n\tif is_century(year) {\n\t\treturn is_divisible_by(year, 400)\n\t}\n\treturn is_divisible_by(year, 4)\n}\n' \
    > tests/example-multiple-files/years.v
printf 'module main\n\nfn is_century(year int) bool {\n\treturn is_divisible_by(year, 100)\n}\n\nfn is_divisible_by(year int, by int) bool {\n\treturn year %% by == 0\n}\n' \
    > tests/example-multiple-files/rules.v

# --- whitespace that v fmt should flatten ---------------------------------
mkdir -p tests/example-messy-whitespace/.meta
cp tests/example-leap/.meta/config.json tests/example-messy-whitespace/.meta/config.json
{
  printf '\n\n\n'
  printf 'module main\n'
  printf '\n'
  printf 'fn is_leap_year(year int) bool {\n'
  printf '   if year %% 100 == 0 {   \n'
  printf '\t\treturn year %% 400 == 0\n'
  printf '   }\n'
  printf 'return year %% 4 == 0\n'
  printf '}\n'
} > tests/example-messy-whitespace/leap.v

# --- comments --------------------------------------------------------------
mkdir -p tests/example-comments/.meta
cp tests/example-leap/.meta/config.json tests/example-comments/.meta/config.json
cat > tests/example-comments/leap.v <<'V'
module main

// Check the Gregorian rule: divisible by 4, except centuries, except 400s.
fn is_leap_year(year int) bool {
	// the century case is the fiddly one
	if year % 100 == 0 {
		return year % 400 == 0
	}
	return year % 4 == 0
}
V

# --- a solution that does not parse (leftover <TYPE> placeholder) ----------
mkdir -p tests/example-unparseable/.meta
cat > tests/example-unparseable/.meta/config.json <<'JSON'
{
  "files": {
    "solution": [
      "grade-school.v"
    ]
  }
}
JSON
cat > tests/example-unparseable/grade-school.v <<'V'
module main

fn add_student(roster <TYPE>, name string, grade int) <TYPE> {
	return error('not implemented yet')
}
V

# --- no .meta/config.json: must fall back to globbing ---------------------
mkdir -p tests/example-no-meta-config
printf "module main\n\nfn is_leap_year(year int) bool {\n    return year %% 4 == 0 && (year %% 100 != 0 || year %% 400 == 0)\n}\n" \
    > tests/example-no-meta-config/leap.v

# --- a declared solution file that is not there: must be a hard error -----
mkdir -p tests/example-missing-file/.meta
cat > tests/example-missing-file/.meta/config.json <<'JSON'
{
  "files": {
    "solution": [
      "leap.v"
    ]
  }
}
JSON
touch tests/example-missing-file/.expect-error

echo "fixtures created:"
ls -1 tests/
