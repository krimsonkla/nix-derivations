# Packaging the Clojure agent tooling

A plan for adding `clj-surgeon` as a babashka `cli`. Written by an agent working
in the `knot` repository, whose `AGENTS.md` makes the tool mandatory and which
has no nixpkgs source for it.

`clojure-mcp-light` — the source of `clj-nrepl-eval` and `clj-paren-repair` — is
**not** planned here. It is blocked on a decision recorded at the end, not on
effort.

Read `CONTRIBUTING.md` first. Everything below is expressed in its vocabulary
and is subordinate to it; where the two disagree, `CONTRIBUTING.md` wins and
this file is wrong.

## A correction, and the trap that caused it

This plan has been wrong twice about `clojure-mcp-light`, in opposite
directions, and the second error is worth recording because the trap is
reusable.

A first draft called it blocked behind Maven vendoring, reasoning only from
`bb.edn`'s `:deps`. A second draft called that wrong and declared the tool
packageable, on the strength of running both commands from source under
`env -i` with a pinned empty `bb.edn`. **That test was invalid.** Two reasons,
both verified:

- **All three entry files call `add-deps` on line one**, before the `ns` form:
  `(babashka.deps/add-deps '{:deps {parinferish/parinferish {:mvn/version ...}}})`
  in `nrepl_eval.clj`, and the `cljfmt` equivalent in `paren_repair.clj` and
  `hook.clj`. That triggers Maven resolution at load time, before the classpath
  is consulted at all, so no arrangement of `--classpath` can route around it.
  The second draft missed this by extracting the `ns` form with a pattern
  anchored at `(ns `, which structurally cannot show a line above it.
- **`env -i` does not isolate babashka.** It is a GraalVM native image and takes
  `user.home` from the OS passwd entry, not from `$HOME`. Under
  `env -i HOME=/tmp/scratch` it still reports `user.home = /Users/<user>` and
  still reads the real `~/.m2`. The "hermetic" run resolved `add-deps` against
  a warm cache that an earlier, admittedly non-hermetic run in the same session
  had just populated — its `Downloading: parinferish/…jar from clojars` line
  was the evidence, and it was not acted on.

In a sandbox with no network and no populated `~/.m2`, resolution fails:

```
Error building classpath. Failed to read artifact descriptor for org.clojure:clojure:jar:1.12.4
```

Neither an empty `bb.edn` nor one declaring the same libraries as `:local/root`
avoids it; `add-deps` resolves regardless.

**To test a babashka tool for source-only operation, build it in the sandbox.**
`env -i` is not a substitute, and a passing run on a developer machine proves
nothing about a machine whose `~/.m2` is cold.

`clj-surgeon` is unaffected by any of this: its `bb.edn` declares no `:deps`,
it calls `add-deps` nowhere, and its behaviour has been confirmed
independently by a second agent working in this repository.

## What the tool is

`clj-surgeon` performs structural operations on Clojure namespaces — outline a
file, show one form, move or rename a form. It is a babashka CLI whose entry
point is `clj-surgeon.core`, invoked upstream through `bbin`.

Upstream: <https://github.com/realgenekim/clj-surgeon>

## Findings already verified

### Pinned rev and hash

```
rev  = "8325ff425410569ddc7ecd2fd01afaf8f6a8b140";
hash = "sha256-fQxU7fJMJ7axPRU8NCXuMbRiL14j462zjHEn32S3iQ0=";
```

This is the rev the `knot` dev container pins, and a 40-character commit sha per
convention.

### The copy-source template applies

`clj-surgeon` needs only its own `src` on the classpath. Its `bb.edn` declares
no `:deps`; the `cheshire`, `sci` and `rewrite-clj` entries in its `deps.edn`
serve the JVM and MCP paths, and babashka bundles all three. It reports
`{:tool "clj-surgeon", :version "0.1.0"}`.

Given the trap above, confirm this in the sandbox as part of the install check
rather than trusting a developer-machine run — which is what the install check
below is for.

### Version

The tool reports `0.1.0`. Upstream publishes no release tags — its tag list
holds only feature-branch markers, none at the pinned rev — so
`CONTRIBUTING.md`'s "version is the tag without `v`" cannot be met literally.
Record that deviation in the package README's rationale rather than leaving it
implicit.

### What it needs from its environment

Its ops split on this, and the split drives both the wrapper and the install
check. `:cat` — the op `knot` leans on hardest — runs with no external
executable and no environment at all. `:ls` refuses cleanly without the
admission gate:

```
{:error-type :analyzer-authority-unverified,
 :cause-error-type :clj-kondo-admission-unavailable,
 :error "Forward-reference analyzer authority is unavailable"}
```

Three things must therefore reach the tool at runtime, none of which
`wrapIsolated` can currently express:

- `CLJ_SURGEON_CLJ_KONDO_ADMISSION`, naming the admission script. That script
  ships inside the pinned source at `resources/clj-kondo-admission.py`, so no
  second fetch and no extra registry row are needed. It carries a
  `#!/usr/bin/env python3` shebang and needs `patchShebangs`.
- `clj-kondo` on `PATH`, which the admission gate execs.
- `ripgrep` on `PATH`. Optional to correctness but not to quiet: a missing `rg`
  makes the tool print a two-line warning to stderr and fall back to `grep`, so
  `grep` must be present too if `PATH` is closed rather than inherited.

## Constraints this repository imposes

**`wrapIsolated` only unsets.** Its signature is `{family, exe, name, flags}`
and it emits `--unset` per scrub variable plus `--add-flags`. There is no way to
set a variable or extend `PATH`. This is the one change to shared machinery the
plan requires.

**The hostile fixture directories are compared to the family table for
equality.** The isolation guard diffs family names against
`tests/fixtures/isolation-hostile/*/`, so a new directory there — a per-package
one, say — turns that test red. The babashka fixture is also resolved per
family, not per package, and its only hijack namespace is `knot.main`, which
means the classpath-shadowing half of the hostile run is a vacuous pass for
every babashka tool added after `knot`. The fix belongs inside the existing
directory, not beside it.

**`require-all.clj` does not generalise.** It requires every namespace under
`src/`. That is safe for `knot`, which has no JVM-only code; `clj-surgeon` ships
66 namespaces of which roughly 30 are `mcp_*` modules needing clojure-mcp,
jetty and nrepl. Requiring all of them under babashka fails by design.

**The count pins are absolute, not relative.** They live in several places and
all must move together, or the fixture guards go red for the wrong reason.

## The work

Ordered by dependency. Each task names its subject; none is safe to skip.

### Extend wrapIsolated with environment and path support

In `lib/isolation.nix`, give `wrapIsolated` two optional arguments — one for
variables to set, one for store paths to put on `PATH` — defaulted so the
existing `knot` call site keeps working untouched. Do not change `knot`.

Prefer setting `PATH` outright over prefixing it. A `cli` in this repository
owns a private runtime, and a closed `PATH` is the shape that matches; a prefix
leaves the consumer's `PATH` reachable behind ours, which is the composition
hazard the kind exists to prevent. Whichever is chosen, the reasoning belongs in
the comment above the function, which is where the rest of the family table
explains itself.

One property to preserve deliberately: the guard's `detect_family` matches a
shell wrapper on a line anchored at `^exec`, so `export PATH=` and
`export CLJ_SURGEON_...=` lines emitted ahead of it do not disturb family
detection. This holds for `makeWrapper` and **not** for `makeBinaryWrapper`,
whose fallback branch takes the first store path found anywhere in the binary
and could pick a `PATH` entry instead of the interpreter. Stay on
`makeWrapper`.

### Add the clj-surgeon hijack namespace to the babashka fixture

Inside `tests/fixtures/isolation-hostile/babashka/hijack/`, add
`clj_surgeon/core.clj` declaring `(ns clj-surgeon.core)` with a `-main` that
prints the `HIJACKED-BY-CWD` marker, mirroring the `knot` namespace already
there. Both sit on the one classpath the fixture's `BABASHKA_CLASSPATH` points
at, so the directory set is unchanged and the family-equality test stays green.

The existing `bb.edn` in that fixture needs no change: its `:deps` value is
deliberately invalid EDN, which trips any tool that honours the working
directory's `bb.edn`, and that half already generalises.

### Write the package

`pkgs/by-name/cl/clj-surgeon/package.nix`, following
`pkgs/by-name/kn/knot/package.nix` closely — `stdenvNoCC.mkDerivation`,
`dontBuild = true`, copy `src` and `resources` into `$out/lib/clj-surgeon`, then
wrap with the extended `wrapIsolated`.

```
kind = "cli";
bins = ["clj-surgeon"];
smoke.clj-surgeon = [["--version"]];
runtime = "babashka";
```

**One smoke vector, and that is the considered answer rather than an
oversight.** A smoke vector is re-run from a hostile directory under a hostile
environment and must print identical bytes both times, so it has to be hermetic
and argument-free. `--version` is; `:cat` needs a file argument, and a relative
path resolves differently between the clean run and the hostile copy. The
richer exercises belong in `installCheckPhase`, where `$out` is in scope — which
is exactly how the `knot` package splits two smoke vectors from a much longer
install check. Do not promote an op into `smoke` to make the number look better.

### Write the install check

Model it on `knot`'s, keeping the same four moves: namespaces load, the runtime
floor holds, the declared commands work under `env -i`, and the output is
byte-identical from a hostile directory and environment.

This phase is also where the source-only claim is actually established, because
it runs in the sandbox with no network and no populated `~/.m2`. A regression in
which some future rev adds an `add-deps` line fails here, by name, which is
exactly what the developer-machine test failed to catch.

Two adaptations are required.

Replace the `require-all.clj` step. Requiring one namespace loads its whole
transitive closure and fails by name when something in that closure is
unbundled, so a small `require-main.clj` taking the entry namespace as an
argument gives the same guarantee as `knot`'s glob without dragging in the
`mcp_*` modules. Leave `knot`'s `require-all.clj` alone.

Exercise both sides of the admission split, because that is the part most likely
to rot: `:cat` against a file under `$out/lib/clj-surgeon/src` must succeed, and
`:ls` against the same file must succeed too — the second proves the admission
script and `clj-kondo` actually reached the tool through the wrapper, which is
the whole point of the wrapper change. A build where `:ls` still reports
`:clj-kondo-admission-unavailable` has shipped a broken gate and must fail here.

### Register the package

- Add the entry to `pkgs/default.nix` with `kind = "cli"`.
- Write `pkgs/by-name/cl/clj-surgeon/README.md` with the five required headings
  and one of the four classification words. `migrate` is the honest choice: a
  general-purpose Clojure utility with no reason to stay private forever, simply
  not in nixpkgs yet. Record the version deviation under its rationale heading.
- Add the registry row to `tests/hash-registry.txt`. One `fetchFromGitHub` means
  exactly one row:

```
clj-surgeon      hash        fetch     fetchFromGitHub
```

### Move the count pins

One more package, one more cli, one more smoke vector.

In `tests/hash-registry.bats` the registry count pin goes from one to two. In
`tests/package-list.bats` the package count pin moves the same way — read the
guard, which carries more than one literal.

In `tests/isolation.bats`, the default pin `1 1 0 0 9 2` becomes `2 2 0 0 9 3`.

In `flake.nix`, every `fixtureGuard` pin string is absolute and all of them
move. There are eleven:

| Current       | Becomes       | Guards                                                                                                                                                                                                    |
|---------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `2 1 1 0 9 2` | `3 2 1 0 9 3` | `isolation-library-green`, `isolation-red-wrong-set`                                                                                                                                                      |
| `2 1 0 1 9 2` | `3 2 0 1 9 3` | `isolation-asset-green`, `isolation-red-asset-bin`                                                                                                                                                        |
| `2 2 0 0 9 3` | `3 3 0 0 9 4` | `isolation-python-green`, `isolation-red-python-leak`, `isolation-red-leak`, `isolation-red-unkinded`, `isolation-red-missing-subject`, `isolation-red-misdeclared-runtime`, `isolation-red-unknown-family` |

Recompute rather than trusting the table if the tree has moved since this was
written. A red fixture whose pins are stale still fails, but for the wrong
reason, and its `grep` for the fixture name may not find it — which reads as a
correctly-refused red when it is nothing of the kind.

## Verifying the result

`bats tests/` and `nix flake check`, per the bump procedure. Beyond a green run,
three things are worth confirming by eye, because each is a way this change
could pass while being wrong:

- The isolation guard's own report says three smoke vectors and two cli. The
  counts it prints are the evidence the new vector was actually enumerated.
- `clj-surgeon :ls` succeeds through the installed wrapper. Under `env -i` with
  only `$out/bin` on `PATH`, it must not report
  `:clj-kondo-admission-unavailable`.
- The hostile run genuinely exercises the new hijack namespace. Temporarily
  breaking the wrapper's `BABASHKA_CLASSPATH` scrub should turn the guard red
  naming `clj-surgeon`; if it stays green, the fixture namespace is misspelled
  and is testing nothing.

## The clojure-mcp-light decision

Packaging it requires neutralizing three load-time `add-deps` calls. Three ways,
none of them free:

**Patch upstream.** Convention 4 wants a patch tied to an upstream PR or commit
URL and forbids vendored forks, so this means actually opening a PR — the change
is small and defensible on its merits, since `add-deps` is wrong for any
consumer supplying the classpath itself. It puts the package on a third party's
review timeline.

**Ship a launcher that stubs `add-deps`.** Faster, but it is a fork wearing a
different hat, and it collides with the isolation contract: the obvious
mechanism is `BABASHKA_PRELOADS`, which is a variable the babashka family
*scrubs*. A wrapper that unsets it and then sets it to our own shim is
re-establishing the very channel the hostile fixture exists to prove closed.
Defensible only with that reasoning written down next to it.

**Vendor a Maven repository** as a fixed-output derivation and let `add-deps`
resolve offline. Honest, and the general capability this repository would need
anyway for any JVM package — but it is a new capability, not a new package.

**Recommendation: drop it from scope and ship `clj-surgeon` alone.** These two
commands are the lowest-value gaps of the set — `bb -e` substitutes for
`clj-nrepl-eval` and `cljfmt` is already available to the consumer's shell —
while `clj-surgeon` is a hard rule in `knot`'s `AGENTS.md` and is verified
ready. Blocking the high-value package on its low-value siblings is the wrong
sequencing. If the tools are wanted later, the upstream patch is the route that
keeps convention 4 intact.

## What this plan does not cover

`clojure-mcp` — the full MCP server, distinct from `clojure-mcp-light` — is not
planned here. It is a JVM tool with a real Maven dependency tree (nrepl, jetty,
slf4j), so it needs the vendoring capability described above. It was not
investigated to the same depth as the others, so treat "needs vendoring" as a
strong expectation rather than a verified finding.

One constraint is worth recording now, because it is easy to discover late: if
`clojure-mcp` is ever packaged it must be an uberjar wrapped on `java` directly.
`detect_family` classifies the `clojure` launcher script as the `shell` family
and would refuse a launcher-based wrapper as a misdeclared runtime.

`bbin` needs nothing from this repository — nixpkgs ships it. It is worth
knowing that it pulls a full `graalvm-ce` closure, so a consumer adding it pays
roughly 300 MiB for a tool only needed to install babashka scripts from source.
