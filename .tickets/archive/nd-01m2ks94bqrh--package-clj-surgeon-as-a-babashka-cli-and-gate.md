---
id: nd-01m2ks94bqrh
title: Package clj-surgeon as a babashka cli, and gate shell out of package expressions
status: closed
type: task
priority: 2
mode: hitl
created: '2026-09-16T00:18:46.774817Z'
updated: '2026-09-16T05:28:18.820732Z'
closed: '2026-09-16T05:28:05.139277Z'
assignee: ''
---

## Context

`knot`'s `AGENTS.md` makes `clj-surgeon` mandatory and nixpkgs has no source
for it, so it is packaged here. The plan is
`docs/clojure-tooling-packaging-plan.md`.

`clojure-mcp-light` is deliberately out of scope. All three of its entry files
call `babashka.deps/add-deps` on line one, which resolves against Maven at load
time and fails in a sandbox with no network and a cold `~/.m2`. The plan
records the three ways to neutralize that and recommends deferring; nothing
here reopens it.

## Scope

Package `clj-surgeon` as a babashka `cli`: the expression, its README carrying
the `migrate` classification and the version deviation (upstream publishes no
release tags), its registry row, the hijack namespace in the babashka hostile
fixture, and every count pin that moves with a second package.

Its wrapper needs more than the scrub: `CLJ_SURGEON_CLJ_KONDO_ADMISSION` naming
the admission script that ships in the pinned source, and a closed `PATH`
carrying clj-kondo, ripgrep and grep. That capability does not exist in the
shared wrapper today and is part of this work.

## No embedded shell in a package expression

A second rule lands with it: a package expression declares a package and does
not carry the shell that builds one. Every phase becomes
`source ${./scripts/<name>.sh}` with the script in the expression's own
`scripts/` directory. This governs `pkgs/by-name/` and the isolation fixtures,
which are package expressions too; `flake.nix` and `lib/` are not governed.

The rule is not cosmetic. Shell inside a Nix string is shell no linter reads
and no reviewer can quote-check, because what bash finally sees is what
survived Nix string escaping first. Converting the existing install check
surfaced a live instance: its hostile environment variables were passed through
an unquoted variable and split into separate words, so that half of the
isolation check had not been running.

Existing packages and fixtures convert with it, and `wrapIsolated` retires in
favour of a shell helper fed by the family table, so the scrub list stays
single-source without Nix generating bash.

## Verification

`bats tests/` and `nix flake check` green, the isolation guard's own report
naming the new counts, and `clj-surgeon :ls` succeeding through the installed
wrapper under an empty environment rather than refusing with
`:clj-kondo-admission-unavailable`.

## Notes

**2026-09-16T05:28:18.820732Z**

Closed against draft PR #10 (https://github.com/krimsonkla/nix-derivations/pull/10), commits 82ab1fa and 9b369fa.

Delivered: clj-surgeon packaged as a babashka cli with the admission gate reaching clj-kondo through the wrapper; the no-embedded-shell rule as convention 13, enforced by tests/nix-scripts.bats over pkgs/by-name and the isolation fixtures; wrapIsolated retired for lib/scripts/wrap-isolated.sh fed by the family table; knot and nine fixtures converted; every count pin moved.

Verified: bats tests/ 34/34 and both commits plus the push through dev-gate at GATE EXIT=0. nix flake check passed on this tree's package content, run before the .editorconfig and chore commits were added; CI re-runs it on the PR.

Two findings recorded rather than papered over. clojure-mcp-light stays out of scope because all three entry files call babashka.deps/add-deps at load time, which needs Maven and fails in a sandbox; an earlier plan had called it packageable on the strength of a run that was silently resolving against a warm ~/.m2. And of the two variables the babashka family scrubs, only BABASHKA_PRELOADS is load-bearing for wrappers shaped like these, since bb lets an explicit --classpath beat BABASHKA_CLASSPATH and --config beat the working directory's bb.edn, which makes the hostile fixture's hijack namespaces inert for knot as much as for clj-surgeon. The package README says so.

Closed while the PR is still draft and unreviewed, at the developer's instruction, so the archive move ships in the same branch. Review feedback reopens this rather than landing silently.
