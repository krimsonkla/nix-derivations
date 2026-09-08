# knot

## Upstream

https://github.com/UniSoma/knot (MIT)

## Pinned rev

5c2a42062e94809b1a51df372cab78f9f750fe52 (tag v0.12.0)

## Why here, not nixpkgs

nixpkgs has no `knot` attribute (`knot-dns` and `knot-resolver` are other
projects). knot is a babashka program whose whole runtime is the library set
bundled inside babashka: `bb.edn` declares no `:deps`, so there is nothing to
fetch and nothing to lock. What "pinned" means for it is proven at build time
rather than declared: every namespace under `src` is required under the
consumer's babashka (`require-all.clj`; the flake check
`knot-namespace-check-red` keeps that file honest), the babashka is at least
the floor `bb.edn` states, and the two commands a consumer's shell is promised
run identically from a hostile directory and environment. The runtime is pinned
only as far as each consumer's nixpkgs pins its babashka: the overlay builds
with the consumer's `callPackage`, so a consumer on another nixpkgs builds
locally and these checks run against the babashka that will run knot.

Limits: the namespace check catches what a namespace requires at load time,
not a library pulled in dynamically inside a function; a namespace with
load-time side effects fails it for a reason that is not a missing dependency.

## Bump procedure

Per `CONTRIBUTING.md` › Bumping. `version` is the tag without `v`.

## Patches

None.
