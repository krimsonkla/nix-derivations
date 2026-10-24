---
id: nd-01m5nx68t22y
title: Bump knotview to 91f905d (1.3.0) for related tickets in full and status coloured by role
status: closed
type: task
priority: 2
mode: hitl
created: '2026-10-24T02:52:41.666411Z'
updated: '2026-10-24T03:00:47.905629Z'
closed: '2026-10-24T03:00:47.905629Z'
assignee: Jason Risch
---

## Description

knotview's main is 5 commits past c5d8ff4, the rev this repository pins, and its
pyproject.toml now says 1.3.0. One change reaches this package: the ticket page shows each
related ticket (children, blockers, blocking, linked and siblings) in the full row every
list uses, and each ticket's status is a pill coloured by the role the status plays in the
project's workflow (intake, active, stage, closing, terminal), on every list, the tree, the
overview and the compare page. Rows now lead with type and status. The rest bump ruff,
fastapi, pylint and a CI action, which this build does not read.

Move the pin to knotview's current main, 91f905db89794fb71c18238dba1ac8660cc53c92.

## Design

A bump per CONTRIBUTING.md: the rev moves to the new 40-character sha, the fetch hash is
re-derived, and the README's pinned rev line follows. No count pin or registry row moves.

knotview still has no tags; its CHANGELOG lists 1.3.0 as unreleased. The package README's
rule for an untagged upstream is that version equals pyproject.toml, and the install check
enforces it, so version moves to 1.3.0.

The four runtime Python dependencies are unchanged; the version is the only pyproject.toml
change. The new module panel/related.py imports only the standard library and knotview, and
the import check reaches it by walking the package. The install copies src/knotview whole,
so the new _status.html template ships without a glob change.

The status roles come from fields knot already reports (declared statuses, terminal
statuses and the active status), and the related rows read each ticket's deps, a standard
ticket field. knotview still asks for knot 0.15.0 or later, which this repository ships.

## Done when

- The knotview rev is 91f905d's full sha with a real fixed-output hash, and version is
  1.3.0, equal to pyproject.toml's.
- The build's import check loads every module including panel/related.py, and the version
  check, smoke vectors and isolation check pass against the new source, sandboxed.
- panel/templates/_status.html ships in the output.
- The package README's pinned rev line names the new sha.
- A ticket page and a list served by the built panel over this repository, with knot
  0.15.0, show related tickets in full and status pills.
- bats tests/ and nix flake check pass sandboxed.