---
id: nd-01m5k77nw0nk
title: Bump knotview to c5d8ff4 (1.2.0) for the leverage-ordered ready queue, progress by tag and worktree compare
status: closed
type: task
priority: 2
mode: hitl
created: '2026-10-23T01:50:30.272647Z'
updated: '2026-10-23T02:57:46.296116Z'
closed: '2026-10-23T02:57:46.296116Z'
assignee: Jason Risch
---

## Description

knotview's main is 8 commits past 86384bf, the rev this repository pins, and its
pyproject.toml now says 1.2.0. Two releases reach this package:

- 1.1.0 adds three charts over time on the overview, behind the gear: open tickets at the
  end of each week, tickets opened and closed each week, and lead time from created to
  closed. They come from each ticket's created and closed times, so the panel still keeps
  no history.
- 1.2.0 orders the ready queue by how many tickets closing each one frees (knot's
  leverage), then by priority, and each ready row says "frees N". It adds a chart of
  progress by tag on the overview, and a Compare page, /compare?with=<worktree>, that
  compares the backlog of two worktrees git lists.

The rest bump ruff, black, fastapi, pylint and pillow in uv.lock or the dev group, which
this build does not read.

Move the pin to knotview's current main, c5d8ff48dbdc2959574a4ae025f8ee7050a87ebf.

## Design

A bump per CONTRIBUTING.md: the rev moves to the new 40-character sha, the fetch hash is
re-derived, and the README's pinned rev line follows. No count pin or registry row moves.

knotview still has no tags; its CHANGELOG lists 1.1.0 and 1.2.0 as unreleased. The package
README's rule for an untagged upstream is that version equals pyproject.toml, and the
install check enforces it, so version moves to 1.2.0.

The four runtime Python dependencies are unchanged; the only other pyproject.toml change
across both releases is the dev-group pillow floor. The new modules, panel/trend.py and
panel/comparison.py, import only the standard library and knotview itself; app.py newly
imports starlette's TrustedHostMiddleware, and starlette is part of fastapi's closure. The
import check reaches every new module by walking the package. The install copies
src/knotview whole, so the new templates (_trend.html, _by_tag.html, compare.html) ship
without a glob change.

knotview 1.2.0 still asks for knot 0.15.0 or later, which this repository ships, and the
leverage it shows was already read from knot's JSON before this bump. The Compare page
reads the other worktree through the same git worktree list the dropdown uses, so git
stays optional and comes from the consumer's PATH.

## Done when

- The knotview rev is c5d8ff4's full sha with a real fixed-output hash, and version is
  1.2.0, equal to pyproject.toml's.
- The build's import check loads every module including panel/trend.py and
  panel/comparison.py, and the version check, smoke vectors and isolation check pass
  against the new source, sandboxed.
- The new templates _trend.html, _by_tag.html and compare.html ship in the output.
- The package README's pinned rev line names the new sha.
- bats tests/ and nix flake check pass sandboxed.