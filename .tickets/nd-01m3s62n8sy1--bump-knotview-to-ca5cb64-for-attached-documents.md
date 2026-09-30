---
id: nd-01m3s62n8sy1
title: Bump knotview to ca5cb64 for attached documents in the panel
status: open
type: task
priority: 2
mode: hitl
created: '2026-09-30T12:54:20.184896Z'
updated: '2026-09-30T12:54:20.422942Z'
assignee: ''
---

## Description

knotview's main has moved 36 commits past the rev this repository pins. The change
that matters is attached documents in the panel: a ticket page now shows the documents
knot 0.15.0 lets a ticket own, which this repository started shipping in #16. Alongside
it are panel fixes: each overview count equals the list its link opens, the integrity
card links the tickets its issues name, and a ticket with no id no longer turns every
page into a 503.

Move the pin to knotview's current main, ca5cb6466906da5a6933100077e387afa031933e.

## Design

A bump per CONTRIBUTING.md: the rev moves to the new 40-character sha, the fetch hash is
re-derived, and the README's pinned rev line follows. No count pin or registry row moves.

knotview has no tags and its pyproject.toml still says 0.1.0 at the new rev, so version
stays 0.1.0. That is the rule the package README states for an untagged upstream, and the
install check refuses a version that disagrees with pyproject.toml. Upstream's own
CHANGELOG says v0.1.0 is to be tagged at the commit that is published, and that tag does
not exist yet.

Nothing the derivation depends on changed: the four runtime dependencies are the same,
the package-data globs cover the new templates and script, and the three new modules are
reached by the import check walking the package. uv.lock moved only for dev tools, which
this build does not read.

## Done when

- The knotview rev is ca5cb64's full sha with a real fixed-output hash, and version
  still equals pyproject.toml's.
- The build's import check loads every module including the new ones, and the version
  check, smoke vectors and isolation check pass against the new source, sandboxed.
- The new templates and script ship in the output, so the documents feature is present
  in what consumers get.
- The package README's pinned rev line names the new sha.
- bats tests/ and nix flake check pass sandboxed.