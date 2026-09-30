---
id: nd-01m37ya88qs0
title: Package glci as a go cli
status: open
type: task
priority: 2
mode: hitl
created: '2026-09-23T20:11:35.062600Z'
updated: '2026-09-23T20:11:35.234110Z'
assignee: ''
---

## Description

glci runs a GitLab CI/CD pipeline locally: it compiles .gitlab-ci.yml the way GitLab
does, then runs each job through the official gitlab-runner in a local container. It
answers what a pipeline will actually do without pushing, which is the loop this
repository's consumers are otherwise paying a push and a wait for.

Upstream is gitlab.com/gitlab-org/ci-cd/runner-tools/glci, MIT, written in Go. nixpkgs
has no glci attribute.

## Design

buildGoModule over fetchFromGitLab at the v0.8.0 tag. The kind is cli and the runtime
family is none: a native Go executable, so there is no interpreter to scrub and no
wrapper to build.

glci stamps pkg/version.Commit through ldflags, and resolves the container image it runs
jobs in by that commit. An unstamped build is a dev build, which falls back to a local
image tag a consumer will not have, so the derivation stamps the pinned rev and the
binary finds the published image built from the same source.

This is the first package here with a lockfile, so it brings two registry rows rather
than one: the source hash, and vendorHash against go.sum. That flips the hash registry's
lockfile half from zero rows to one, which is where its Test B first runs for real and
where its count pin moves off the day-one literal. The README's residual risk saying the
lockfile half ships with zero rows stops being true and is rewritten.

The rev-count assertion in the hash registry guard compares every rev under pkgs against
the fetchFromGitHub rows alone. glci is the first fetchFromGitLab package, so that
assertion counts one rev it has no row for and goes red. It is widened to count both
fetchers.

## Done when

- glci builds from a pinned 40-character rev with real fixed-output hashes for both the
  source and the vendored modules, sandboxed, on both supported systems.
- The binary reports the pinned commit, so the image it resolves is the one built from
  the packaged source.
- The cli kind holds: bin/ is exactly the declared command, nothing propagates, and the
  guard detects the none family rather than an interpreter.
- Both smoke vectors print the same bytes from a hostile directory and environment.
- The hash registry carries one row per captured hash, its lockfile count pin moves off
  zero, and its rev assertion counts fetchFromGitLab.
- The README's residual risk about zero lockfile rows is rewritten, and the charter
  guard's bullet count still holds.
- Every guard count pin the package moves is bumped, and bats tests/ and nix flake check
  pass sandboxed.