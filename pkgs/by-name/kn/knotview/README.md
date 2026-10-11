# knotview

## Upstream

https://github.com/krimsonkla/knotview (MIT)

## Pinned rev

86384bf30107773e75a5d27d6020f48dec836943 (no tag; version 1.0.0 from
`pyproject.toml`)

## Why here, not nixpkgs

nixpkgs has no `knotview` attribute, and would not take one: it is first-party
code with one consumer, packaged here so a shell can take the panel the same
way it takes `knot`. The two belong together — knotview is a reader of knot's
JSON and runs `knot` as a process — and a consumer that pinned one from a
flake and built the other by hand would have two ways to be out of date.

The runtime is the four libraries `pyproject.toml` declares (fastapi, jinja2,
markdown-it-py, uvicorn), taken from the consumer's own nixpkgs through
`python3.withPackages`, so the panel builds against the python that will run
it. Nothing is vendored and no lockfile is read: the dependency floors are
wide and the pin that matters is the consumer's nixpkgs rev.

`knot` itself is deliberately absent from the closure. knotview names it as a
command and takes `--knot` for an unusual installation, so the tickets layer
supplies it on PATH; that is also why this wrapper sets no PATH of its own,
only the scrub. What a consumer gets is a panel that finds their knot, not a
second copy of it.

`git` comes from the consumer's PATH the same way. knotview runs
`git worktree list` to offer the repository's worktrees in a dropdown in the
panel header, which needs git 2.36 or later. When git is missing or too old,
the panel shows only the directory it was started in, so git is optional.

Limits: the import check catches a dependency a module requires at import
time, not one reached inside a function. The upstream version is read from
`pyproject.toml` rather than from the command, which has no `--version` flag
to ask.

## Bump procedure

Per `CONTRIBUTING.md` › Bumping. There are no tags upstream, so `version` is
the `version` field of `pyproject.toml` at the pinned rev; the install check
fails the build when the two disagree.

## Patches

None.
