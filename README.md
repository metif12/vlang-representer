# V representer

A [representer](https://exercism.org/docs/building/tooling/representers) for the
[V track](https://exercism.org/tracks/v). It takes a submitted solution and
returns a normalized representation of it, so that solutions which differ only
cosmetically can share one mentor's feedback.

## Interface

`bin/run.sh <exercise-slug> <solution-dir/> <output-dir/>`

It writes three files into the output directory, as specified in
[the interface docs](https://exercism.org/docs/building/tooling/representers/interface):

| File | Contents |
|---|---|
| `representation.txt` | the solution, as printed by `v fmt` |
| `representation.json` | `{ "version": 1 }` |
| `mapping.json` | `{}` — no identifiers are renamed, so there is nothing to map back |

## What the normalization actually is

The representation is the output of `v fmt`, and nothing else.

That is a deliberate choice, and worth defending:

- **It is the highest-value normalization available for V.** V accepts both
  `"foo"` and `'foo'` for the same string, and leaves either style standing, so
  two solutions that differ only in quoting are two representations to mentors
  today. `v fmt` also normalizes indentation to tabs, aligns consecutive struct
  fields, and drops leading blank lines in empty bodies.
- **It cannot merge two different solutions.** This is the spec's hard
  requirement, and it is why nothing is stripped *after* formatting. Removing
  blank lines, for example, would rewrite multi-line string literals, so a
  solution holding `'a\n\nb'` and one holding `'a\nb'` would collapse onto a
  single representation.

## Known limitations

- **Comments are preserved.** Two solutions differing only in their comments get
  different representations. Most representers strip comments, but doing so
  safely needs a parse tree, and `v fmt` does not expose one. This is the main
  source of unnecessary representation splits.
- **Local names are not replaced with placeholders.** A student who calls a
  variable `count` and one who calls it `n` get different representations, even
  when the approaches are the same. Renaming identifiers means walking the AST
  and knowing which names the test file pins, which is a larger piece of work.
- **A solution that does not parse is only weakly normalized.** `v fmt` exits
  non-zero and prints nothing for input it cannot parse, which is common since
  students submit half-finished work. Rather than failing, the representer falls
  back to stripping trailing whitespace. Those representations are weaker, and
  they are not comparable to the formatted ones.

## The compiler is pinned, on purpose

`V_VERSION` and `V_SHA256` in the [Dockerfile](Dockerfile) are pinned because the
output of `v fmt` *is* the representation. If the compiler were allowed to float,
a new V release would change the representation of every solution already stored
on the website, and mentor comments would silently stop matching.

Bump the two together, and expect to review the diff of
`tests/*/expected_representation.txt` in the same pull request. Those files are the
contract, not snapshots.

### A `v fmt` bug worth knowing about

On V master, `v fmt` mangles the ternary operator, silently producing invalid V:

```v
// in
return g(y) ? h(y, 400) : k(y, 4)
// out, exit code 0
return g(y)?
h(y, 400)
k(y, 4)
```

The mangling is deterministic, so it does not merge distinct solutions, but the
representation is not valid V. This is a bug in V rather than in this
representer, and it is worth reporting upstream. It does not affect the pinned
`0.5.2` release, which does not accept a ternary at all — hence the pin.

Also note that `v fmt` is not purely parser-based: it compiles a small tool to a
native binary on first use, so the image needs a C compiler (`tcc` and
`libc6-dev`, not `build-essential`).

## Which files make up a solution

A solution's filename cannot be derived from the slug — `secret-handshake`'s is
`secret_handshake.v`, not `secret-handshake.v` — so `.meta/config.json` is the
source of truth, read with `jq`. Globbing is only a fallback.

The two paths are sorted and de-duplicated so they always agree. They otherwise
disagree: the config lists files in config order and the glob is sorted, which
would give one solution two different representations depending on whether `jq`
happens to be installed in the image. `bin/run-tests-in-docker.sh` checks this
implicitly: the expected files are generated on a host without `jq` and
reproduced inside the image, which has it.

## Development

```sh
bin/run-tests.sh            # against whatever `v` is on your PATH
bin/run-tests-in-docker.sh  # against the pinned compiler; the authoritative run
bin/run-in-docker.sh tests/example-leap
```

`bin/build-fixtures.sh` regenerates the inputs and `bin/build-expected.sh` the
expected outputs. Only run the second when you intend to change a
representation.

### Fixtures

Each directory under `tests/` is a solution plus its expected output. A fixture
may contain an `equivalent-to` file naming another fixture whose representation
must be **identical**; this is how the quote-normalization case is tested.
`.expect-error` marks a fixture that must fail.

| Fixture | What it pins |
|---|---|
| `example-leap` | an ordinary formatted solution |
| `example-double-quoted`, `example-single-quoted` | the pair that must collapse onto one representation |
| `example-string-with-quote` | a string whose quotes cannot be rewritten, so a naive normalizer would corrupt it |
| `example-messy-whitespace` | mixed tabs and spaces, trailing whitespace, leading blank lines |
| `example-comments` | comments survive |
| `example-multiple-files` | several solution files |
| `example-no-meta-config` | no `.meta/config.json`, so the glob fallback runs |
| `example-unparseable` | leftover `<TYPE>`, so the weak fallback runs |
| `example-missing-file` | a declared solution file that is not there, which is a hard error |

### Performance

A cold container run, including container start, takes about **0.6 s** against a
20 second budget. `v fmt` itself is about 20 ms per file.

## Licence

AGPL-3.0, matching the other Exercism representers.
