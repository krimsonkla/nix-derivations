# clj-surgeon

## Upstream

https://github.com/realgenekim/clj-surgeon (MIT)

## Pinned rev

8325ff425410569ddc7ecd2fd01afaf8f6a8b140

Upstream publishes no release tags — its tag list holds only feature-branch
markers, none at the pinned rev — so `CONTRIBUTING.md`'s "version is the tag
without `v`" cannot be met literally here. `version` is `0.1.0`, the value the
tool itself reports through `--version`, and the install check asserts the
installed command still reports it. This is the rev the `knot` dev container
pins.

## Why here, not nixpkgs

Classification: **migrate**. nixpkgs has no `clj-surgeon` attribute. It is a
general-purpose Clojure utility with no reason to stay private — it is simply
not upstream yet — and `knot`'s `AGENTS.md` makes it mandatory, so it moves
here until nixpkgs ships it.

Like `knot` it is a babashka program whose runtime is the library set bundled
inside babashka: `bb.edn` declares no `:deps`, and nothing in the tree calls
`babashka.deps/add-deps`, so there is nothing to fetch and nothing to lock.
What "pinned" means for it is proven at build time rather than declared. The
install check runs in the sandbox, with no network and no populated `~/.m2`,
which is the only place that claim can be established: babashka is a GraalVM
native image that reads `user.home` from the passwd entry rather than `$HOME`,
so a run under `env -i` on a developer machine still resolves against the real
`~/.m2` and proves nothing. A future rev that grows a load-time `add-deps`
call fails the check by name.

Unlike `knot`, the entry namespace is required by name rather than by globbing
`src/` (`require-main.clj`, not `require-all.clj`): roughly 30 of the 66
namespaces here are `mcp_*` modules needing clojure-mcp, jetty and nrepl, and
do not load under babashka by design. Requiring one namespace still loads its
whole transitive closure, so the guarantee is the same for everything the
command actually reaches.

The tool's ops split on what they need from the environment, and the wrapper is
built around that split. `:cat` runs with no external executable and no
variable at all. The forward-reference ops — `:ls` among them — refuse with
`:clj-kondo-admission-unavailable` unless `CLJ_SURGEON_CLJ_KONDO_ADMISSION`
names the admission script and `clj-kondo` is on `PATH` for the gate to exec.
The script ships inside the pinned source, so it costs no second fetch and no
second registry row; its `#!/usr/bin/env python3` shebang is patched to a store
path. `ripgrep` and `grep` are both on the closed `PATH` the wrapper sets,
because the search ops prefer `rg` and warn on stderr when falling back. The
install check exercises `:cat` bare, and asserts directly that everything the
wrapper owes the gate is in place: the wrapper names the admission script, that
script is executable, its shebang was patched to a store path and that
interpreter loads what the script imports, and `clj-kondo`, `rg` and `grep` all
resolve on the closed `PATH`.

It does **not** run a forward-reference op end to end, and that is a property of
the build environment rather than a gap left casually. Resolving the analyzer
canonicalizes `<user.home>/bin/clj-kondo` before it resolves anything, and
babashka is a native image that reads `user.home` from the passwd entry rather
than `$HOME` — the same property that makes an `env -i` run on a developer
machine prove nothing about hermeticity. Inside a sandbox that call reaches for
the real user's home, which the darwin sandbox refuses:
`java.io.UnixFileSystem.canonicalize0` throws `Operation not permitted`, and the
tool surfaces that as an unavailable gate. No variable redirects `user.home`. A
consumer's first forward-reference op is where the whole chain runs; an
end-to-end assertion restored here will go red on any sandboxed darwin builder,
which is what CI is.

Limits: the namespace check catches what a namespace requires at load time, not
a library pulled in dynamically inside a function.

Of the two variables the babashka family scrubs, only `BABASHKA_PRELOADS` is
load-bearing for a wrapper shaped like this one. Verified: `bb` lets an
explicit `--classpath` flag beat `BABASHKA_CLASSPATH`, and an explicit
`--config` beat the working directory's `bb.edn`, so the classpath half of the
hostile run cannot change this command's behaviour whether it is scrubbed or
not. Removing `BABASHKA_PRELOADS` from the scrub does turn the install check
red. The scrub keeps both because the guard holds the wrapper to the family
table rather than to one package's flags, and a future babashka package that
leans on the variable instead of the flag would need it. The hijack namespace
under `tests/fixtures/isolation-hostile/babashka/hijack/` is inert for the same
reason -- for knot as much as for this package. The smoke vector is
`--version` alone — an op needs a file argument, and a relative path resolves
differently between the guard's clean run and its hostile copy, so the richer
exercises live in the install check where `$out` is in scope.

## Bump procedure

Per `CONTRIBUTING.md` › Bumping, with one deviation: `version` does not come
from a tag (see `## Pinned rev`). Take it from what the tool reports at the new
rev, and expect the install check to fail if the two disagree.

## Patches

None. The hostile `bb.edn` and hijack namespace the build's isolation check
writes are a copy of the guard's babashka fixture under `tests/`, kept apart so
the package's hash does not depend on test data.
