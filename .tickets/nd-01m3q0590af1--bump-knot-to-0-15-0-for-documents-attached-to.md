---
id: nd-01m3q0590af1
title: Bump knot to 0.15.0 for documents attached to tickets
status: open
type: task
priority: 2
mode: hitl
created: '2026-09-29T16:32:25.610725Z'
updated: '2026-09-29T16:32:25.763309Z'
assignee: ''
---

## Description

knot 0.15.0 adds documents attached to tickets: typed markdown files a ticket owns,
managed with knot document add, show, replace, delete and list, which a project can
require before a status change through :required-docs in .knot.edn. The feature
landed upstream as UniSoma/knot#1, and 0.15.0 is the first release that carries it.

This repository pins knot at 0.12.0, so every shell that takes knot from here is three
releases behind and has no document command at all. Bump the pin to the v0.15.0 tag.

## Design

A bump per CONTRIBUTING.md: the rev moves to the tag's 40-character sha, the fetch hash
is re-derived, version becomes 0.15.0 and the README's pinned rev line follows. No count
pin moves and no registry row is added, because the attribute path of the one hash does
not change.

What the bump has to prove is what the build already checks, run against the new
source: every namespace still loads under the consumer's babashka, since three releases
may have pulled in a library babashka does not bundle; the babashka floor bb.edn states
still holds; knot --version reports 0.15.0; and the two smoke commands still print the
same bytes from a hostile directory and environment.

bb.edn at v0.15.0 still declares no :deps and keeps the 1.3.0 floor, so no new fetch or
lock is expected.

## Done when

- The knot rev is the v0.15.0 sha with a real fixed-output hash, and version is 0.15.0.
- The build's namespace check, babashka floor check, version check and isolation check
  all pass against the new source, sandboxed.
- knot document --help answers from the built package, so the feature this bump exists
  for is present in what consumers get.
- The package README's pinned rev line names the new sha and tag.
- bats tests/ and nix flake check pass sandboxed.