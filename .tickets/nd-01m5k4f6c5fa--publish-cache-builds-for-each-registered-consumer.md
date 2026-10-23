---
id: nd-01m5k4f6c5fa
title: Publish cache builds for each registered consumer nixpkgs, so follows consumers substitute instead of compiling
status: open
type: task
priority: 2
mode: hitl
created: '2026-10-23T01:02:10.820063Z'
updated: '2026-10-23T01:02:10.917698Z'
assignee: ''
---

## Description

Consumers follow their own nixpkgs (`inputs.nixpkgs.follows`), so the store paths they ask the cache for differ from the ones `publish.yml` builds with this repository's own nixpkgs. Every follows consumer therefore misses the cache and compiles. devenv-layers' consumer-check fails on it (devenv-layers ticket dl-01m4npft6qmg).

Register each consumer's nixpkgs in `consumer-nixpkgs.txt` (one line per consumer, owner/repo allowlist, upstream provenance checked), and have `check.yml` and `publish.yml` build and prove every package per registered ref.

## Acceptance

- `consumer-nixpkgs.txt` lists `layers github:cachix/devenv-nixpkgs/760b85220489f69855e6df78a6d1dad5873f8bf6`, validated by `scripts/consumer-nixpkgs.py` and the `consumer-nixpkgs` bats guard (count pinned, red checks).
- `publish.yml` builds and substitute-proves all packages per registered ref on both systems; `check.yml` builds them on PRs, secret-free.
- A rev not reachable from its upstream branch, or an API failure, fails before any build.