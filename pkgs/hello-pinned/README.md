# hello-pinned

## Upstream

https://github.com/octocat/Hello-World

## Pinned rev

7fd1a60b01f91b314f59955a4e4d4e80d8edf11d

## Why here, not nixpkgs

A placeholder that exercises the whole pipeline at one package: a
`fetchFromGitHub` fetch-kind hash, both guards, `nix flake check` on both
systems, the cachix push, and the tokenless `substitute-only` proof. It is
removed in the same change that adds the first real package, so the package
list never drops to zero.

## Bump procedure

Per `CONTRIBUTING.md` › Bumping.

## Patches

None.
