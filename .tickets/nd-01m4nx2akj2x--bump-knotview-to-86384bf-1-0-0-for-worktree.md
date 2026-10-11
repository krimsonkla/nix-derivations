---
id: nd-01m4nx2akj2x
title: Bump knotview to 86384bf (1.0.0) for worktree switching and the Primer redesign
status: in_progress
type: task
priority: 2
mode: hitl
created: '2026-10-11T16:34:50.609214Z'
updated: '2026-10-11T16:35:45.398274Z'
assignee: Jason Risch
---

## Description

knotview's main is 7 commits past e0bb54b, the rev this repository pins, and its
pyproject.toml now says 1.0.0. Two changes reach this package. The panel can now switch
between a repository's git worktrees from a dropdown in the header. Every page is
redesigned on Primer Primitives, which upstream vendors in the package as primer.css with
its MIT licence. The rest bump ruff, uvicorn, fastapi and pylint in uv.lock, which this
build does not read.

Move the pin to knotview's current main, 86384bf30107773e75a5d27d6020f48dec836943.

## Design

A bump per CONTRIBUTING.md: the rev moves to the new 40-character sha, the fetch hash is
re-derived, and the README's pinned rev line follows. No count pin or registry row moves.

knotview still has no tags. Its CHANGELOG lists 1.0.0 as unreleased, to be tagged at the
published commit. The package README's rule for an untagged upstream is that version
equals pyproject.toml, and the install check enforces it, so version moves to 1.0.0.

The four runtime Python dependencies are unchanged; the only new entry in pyproject.toml
is pillow, in the dev group. The install copies src/knotview whole, so the new static
files, templates and PRIMER-LICENSE ship without a glob change, and the import check
reaches the five new modules by walking the package.

The one new dependency is a command, not a library: worktree switching runs
`git worktree list --porcelain -z`, which needs git 2.36 or later. knotview treats git
as optional: if git is missing, too old, or not in a repository, the panel shows the
launch directory alone, as it did before. So git is handled the way knot is: it comes
from the consumer's PATH, the wrapper still sets no PATH, and the package README says so.
Putting git in the closure would need a PATH the wrapper does not set, and would hide
the consumer's knot.

## Done when

- The knotview rev is 86384bf's full sha with a real fixed-output hash, and version is
  1.0.0, equal to pyproject.toml's.
- The build's import check loads every module including the new ones, and the version
  check, smoke vectors and isolation check pass against the new source, sandboxed.
- primer.css, PRIMER-LICENSE, fold.js and the new templates ship in the output.
- The package README's pinned rev line names the new sha, and it says git is taken from
  the consumer's PATH and is optional.
- bats tests/ and nix flake check pass sandboxed.