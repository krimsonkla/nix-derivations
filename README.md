# nix-derivations

## What this is

Shared Nix derivations for third-party packages that nixpkgs does not ship, or
ships at the wrong version, written once and pinned by every krimsonkla
repository as a single flake input. It sits alongside nixpkgs, not in front of
it: consumers keep their own nixpkgs and take only the packages listed under
`pkgs/` from here.

## Consuming

```nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nix-derivations = {
      url = "github:krimsonkla/nix-derivations/<rev>";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

Either apply the overlay, `nixpkgs.overlays = [ inputs.nix-derivations.overlays.default ]`,
and use `pkgs.<name>`, or take a package directly with
`inputs.nix-derivations.packages.${system}.<name>`. Supported systems are
`x86_64-linux` and `aarch64-darwin`; `x86_64-darwin` and `aarch64-linux`
evaluate to a named "unsupported system" error rather than an attribute-missing
failure.

Built outputs are pushed to a public binary cache after every merge:

```
substituters = https://krimsonkla-nixpkgs.cachix.org
trusted-public-keys = krimsonkla-nixpkgs.cachix.org-1:9WHsyDVPF07aDDPjysKKmovp4LxPztFlSPV2Vj0lZgk=
```

No token is needed to substitute. The `publish` workflow proves this on every
merge by building every package on a fresh runner with no credentials and local
builds forbidden.

This cache is dedicated to this repository and is **in addition to** any cache
a consumer already uses (devenv-layers' own binary-cache layer points at
`krimsonkla`, not here). A consumer therefore adds a second substituter and
public key; nothing here replaces the first.

### Who can write to the cache

The cache `krimsonkla-nixpkgs` exists for this repository alone. Its only
writer is the `publish` workflow's `build` job, which runs in the GitHub
Actions environment `cachix-push`. The write token lives in that environment
as `CACHIX_AUTH_TOKEN`, never in the repository and never at repository scope,
and the environment's deployment-branch policy admits only the default branch.
So a workflow edited on a feature branch, or a fork PR, cannot obtain the token
even if it names the environment: GitHub refuses the job before it starts.
Rotation is: mint a new token in cachix, replace the environment secret, revoke
the old one. Nothing in the repository changes.

## Why public

No packaged source is private, the binary cache is already publicly readable,
and a private flake input would make evaluation itself credentialed for every
consumer, which is the friction that causes packages to be vendored in the
first place. Adding a package whose source is private **reopens** this
decision; it is not accommodated silently.

## Adding a package

Read `CONTRIBUTING.md`. One directory under `pkgs/`, one line in
`pkgs/default.nix`, one row per captured hash in `tests/hash-registry.txt`, and
a README with the five required headings. The guards under `tests/` enforce the
shape, and `tests/named-labels.bats` keeps every label named after its subject
rather than its position.

## CI

Three GitHub Actions workflows:

- `check.yml` on every push and pull request: `nix flake check` in a sandbox on
  `ubuntu-latest` and `macos-latest` (Apple silicon), plus `registry-diff`,
  which re-fetches every changed fetch-kind hash with substitution disabled.
  The three required status checks, named once here and configured in branch
  protection, are `check (ubuntu-latest)`, `check (macos-latest)` and
  `registry-diff`. A flaky darwin run is retried, never made advisory.
- `publish.yml` on merge to the default branch: build every package on both
  systems, push to the cache with a write token minted for this repository
  alone, then `substitute-only` proves a tokenless consumer substitutes.
- `full-registry.yml` weekly, on manual dispatch, and on merges touching
  `pkgs/` or `tests/`: re-fetches every registry row with substitution
  disabled.

GitHub Actions is the gate here. That is a deliberate divergence from
devenv-layers, whose gate is local hooks: a public repository gets free
required checks that `--no-verify` cannot bypass. The repository maintainer
owns the workflow deck.

## Residual risks

- The repository's own `flake.lock` on `devenv-nixpkgs/rolling` is a build-time
  convenience. A consumer that `follows` its own nixpkgs gets no guarantee from
  this repository's green check; that is covered from the consumer side by the
  devenv-layers consumer-integration fixture, which pins both revisions.
- The conventions in `CONTRIBUTING.md` are copies of devenv-layers text and can
  drift from the originals with nothing detecting it. Conventions 4, 7 and 8
  are written-only here; nothing enforces them.
- The lockfile half of the hash registry guard ships with zero rows on day one.
  Its count pin is asserted at 0, and the first lockfile-kind package is where
  that test first goes red and green.
- Branch protection on a single-maintainer repository cannot require a second
  approver. A private dev shell therefore trusts a cache writable through this
  repository's merge path, and the owner can bypass protection. The trust
  surface equals owner-merged changes, the same as before this repository
  existed. Pushes reach the default branch only through the owner, by virtue of
  the collaborator set rather than a push-restriction rule.
- GitHub Actions is the gate of record, which devenv-layers deliberately does
  not use; the two repositories hold different stances on purpose.
- Every merge pushes full closures to the cache and nothing retires old paths;
  cache storage grows without a retention policy.
