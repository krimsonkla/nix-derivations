---
id: nd-01m2pqpc68v6
title: Add a Dependabot config so the sha-pinned actions are told when they go stale
status: open
type: task
priority: 2
mode: hitl
created: '2026-09-17T03:48:46.919494Z'
updated: '2026-09-17T03:48:47.074602Z'
assignee: ''
---

## Description

All three workflows pin their actions by commit sha. A sha never floats, so
nothing currently reports that a newer version of an action exists. The
repository's Dependabot alerts setting is off, and there is no
`.github/dependabot.yml`, so neither half of Dependabot is active here.

Version updates are driven by the config file alone and do not depend on the
alerts toggle, so the file is the part that can be added in-tree.

Found during a security audit of the public repositories.

## Notes

Ecosystems that apply: `github-actions`. The Nix inputs are held by
`flake.lock`, which Dependabot does not cover.