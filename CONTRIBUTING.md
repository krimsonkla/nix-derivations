# Contributing

These conventions travel with the repository as text because no shared harness
does. Read them before touching `pkgs/` or `tests/`.

## Conventions

1. Pinned revs are 40-character commit shas. Never a branch or tag.
2. Every captured hash is a real fixed-output hash. Never `lib.fakeHash`,
   `""`, or a 52-zero placeholder.
3. No runtime network. Builds run with `sandbox = true` on both systems.
4. Patches reference an upstream PR or commit URL in the package README. No
   vendored forks of upstream source.
5. One package per directory at `pkgs/by-name/<xy>/<name>/package.nix`, where
   `xy` is the first two letters of the name (nixpkgs' by-name layout), AND an
   entry in `pkgs/default.nix` naming the file and the package's kind. by-name's
   tree-walk discovery is not used: the explicit entry is what the guards
   enumerate against, so a walk that finds nothing is red, not empty. The
   attribute, directory and `pname` are the upstream name, lowercase, with no
   version or vendor prefix; `version` is the tag without `v`; `meta` carries
   `description` (no leading article, no trailing period), `homepage`,
   `license`, `mainProgram` for a command, and `platforms`. A name nixpkgs
   already ships is a declared override, never an accident.
6. A guard that enumerates its subject reports the size of the set it
   validated, and a test pins that size. A guard whose enumeration breaks open
   matches nothing, exits 0, and is indistinguishable from clean; the pinned
   count is what makes that red.
7. A sentence naming a retired control carries a retirement marker bound to the
   mention. Naming a deleted control as history is fine; asserting it currently
   governs anything is not.
8. No git-tracker references in code comments. Put the reasoning in prose and
   the issue reference in the commit message.
9. Adding a package adds registry rows, one per hash-bearing assignment (a
   package with five `outputHash` lines carries five rows). Removing one
   removes them.
10. Labels name their subject, never their position. No test, heading,
    assertion message or comment is called by an ordinal or a section sign;
    a positional label says nothing and goes stale when something is inserted
    before it.
11. Every hand-packaged derivation a consumer keeps in-tree carries one of the
    four classification words in the README (migrate, keep-local,
    upstream-to-nixpkgs, retire); a consumer's allowlist rejects any other
    word.
12. Every package is one of two kinds, declared in `pkgs/default.nix` and in
    `passthru.kind`. A `cli` owns exactly the commands `passthru.bins` names,
    propagates nothing, and has a private runtime: its wrapper is built with
    `lib/isolation.nix`'s `wrapIsolated`, which unsets every variable the
    runtime family honours, its `passthru.runtime` names that family, and its
    `passthru.smoke` vectors must print the same bytes from a hostile
    directory and environment. The guard does not take the family on trust:
    it follows each command to the interpreter it execs and fails by name
    when that interpreter is another family or one the table lacks, so a
    runtime outside `lib/isolation.nix` is a named failure, never a pass;
    `none` means a native executable. A `library` extends the language set
    `passthru.set` names, through the interpreter's own fixpoint (never an
    attrset merge, which leaves the attribute missing from the interpreter's
    own package set), ships no `bin/`, and is never at top level. A
    consumer's shell composes layers on their own language versions; a
    package that leaks its runtime onto PATH breaks that composition.

Enforcement map: 1 and 2 by the well-formedness test in `tests/hash-registry.bats`;
3 by `sandbox = true` in every CI lane; 5 by `tests/package-list.bats`; 6 by the
count pins in both guards; 9 by the registry enumeration test's set equality;
10 by `tests/named-labels.bats`; 11 by `tests/inventory.bats`, which pins the
scanner's counts (the allowlist that rejects a fifth word is a consumer's own);
12 by `tests/isolation.bats`
with the standing reds `isolation-red-leak`, `isolation-red-unkinded`,
`isolation-red-missing-subject`, `isolation-red-misdeclared-runtime`,
`isolation-red-unknown-family` and `isolation-red-wrong-set`, and the green
witness `isolation-library-green`.
Conventions 4, 7 and 8 are **written-only** here: nothing in this repository
checks them.

## Package README headings

Every `pkgs/by-name/<xy>/<name>/README.md` carries exactly these headings, checked by the
package-list guard:

- `## Upstream`
- `## Pinned rev`
- `## Why here, not nixpkgs`
- `## Bump procedure`
- `## Patches`

## Bumping

1. Edit `rev` in the package expression to the new 40-character sha.
2. Set the fetch `hash` to `lib.fakeHash` and run `nix build .#<name>`.
3. Copy the hash Nix reports into the expression.
4. If the attribute path of any hash changed, update its row in
   `tests/hash-registry.txt`.
5. Update the `## Pinned rev` line in the package README.
6. Run `bats tests/` and `nix flake check`.
