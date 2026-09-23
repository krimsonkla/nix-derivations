---
id: nd-01m37t1gj01d
title: Package knotview as a python cli
status: open
type: task
priority: 2
mode: hitl
created: '2026-09-23T18:56:54.335277Z'
updated: '2026-09-23T18:56:54.508304Z'
assignee: ''
---

## Description

knotview is the read-only panel over a knot backlog, kept in krimsonkla/knotview. A
consumer's shell already takes knot from this repository and builds knotview by hand,
which is two ways to be out of date over a pair of tools that only make sense together.

Package it here as a cli. The runtime is the four libraries pyproject.toml declares,
taken from the consumer's own nixpkgs, behind a wrapper with a private runtime.

knot itself stays out of the closure. knotview names it as a command and takes --knot
for an unusual installation, so the tickets layer supplies it on PATH; that is also why
the wrapper sets no PATH of its own, only the scrub.

## Design

stdenvNoCC over fetchFromGitHub at a pinned rev, with python3.withPackages for fastapi,
jinja2, markdown-it-py and uvicorn. A launcher sits beside the copied package, so python's
own rule of putting a script's directory first on sys.path makes the package importable
and no PYTHONPATH has to survive the scrub.

There is no --version flag to ask, so the install check reads pyproject.toml at the pinned
rev and refuses a version the derivation disagrees with. It also imports every module, which
is where a dependency missing from the closure fails by name rather than on the first page
that reaches it.

The smoke vectors are --help and a name nothing was saved under. Neither reads the working
directory, which the hostile run moves.

## Done when

- knotview builds from a pinned rev with a real fixed-output hash, sandboxed, on both
  supported systems.
- The cli kind holds: bin/ is exactly the declared command, nothing propagates, and the
  wrapper is built from the python family's scrub list rather than a copy of it.
- Both smoke vectors print the same bytes from a hostile directory and environment.
- Every guard count pin the package moves is bumped, and bats tests/ and nix flake check
  pass sandboxed.
- The package README carries the five required headings, and the hash registry carries one
  row per captured hash.