# glci

## Upstream

https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci (MIT)

## Pinned rev

50516e8ccf85514a484295556f578f9d97437707 (tag v0.8.0)

## Why here, not nixpkgs

nixpkgs has no `glci` attribute. The name is contested upstream — there are at
least two unrelated tools called glci — and this is GitLab's own, which
compiles `.gitlab-ci.yml` the way GitLab does and then runs each job through
the official gitlab-runner image. It is new (its first tags are from 2026) and
moving quickly, which is the case this repository exists for: a consumer wants
one pinned rev shared across repositories rather than a version that drifts
per machine.

Two things about the build are worth knowing.

It is the first package here with a lockfile, so it carries two registry rows
rather than one: the source hash, and `vendorHash` over `go.sum`. That is what
brings the hash registry's lockfile half to life — its count pin moves off
zero and its verification re-derives the vendored modules with substitution
disabled.

It is also the first fetched from GitLab rather than GitHub, which is why the
rev assertion in that guard counts both fetchers. `fetchFromGitLab` takes the
nested group as `group` and the last path segment before the repository as
`owner`, so `gitlab-org/ci-cd/runner-tools/glci` is `group` plus `owner` plus
`repo` rather than one slug.

glci stamps `pkg/version.Commit` through `ldflags` and resolves the container
image it runs jobs in by that commit: an unstamped binary is a dev build, and
falls through to a local image tag that exists on a maintainer's machine and
nowhere else. The derivation therefore stamps the same rev it fetched, and the
install check reads the binary's own report back to prove the two agree. That
check also covers a silent failure mode of `-X`: the linker ignores a path
that is not exactly the module path, with no diagnostic.

Limits: glci needs a container engine (Docker or Podman) at runtime, which the
consumer supplies — it is not in this closure, and neither is the runner
image, which glci pulls on first use. Upstream's own test suite drives a real
daemon and does not run in the sandbox, so `doCheck` is false and what is
proven at build time is what the install check states.

## Bump procedure

Per `CONTRIBUTING.md` › Bumping, with one addition: `vendorHash` is a second
captured hash and is re-derived the same way. `version` is the tag without
`v`, and the `rev` in the `let` is spent twice — the fetch and the stamp read
the same binding, so they cannot drift apart.

## Patches

None.
