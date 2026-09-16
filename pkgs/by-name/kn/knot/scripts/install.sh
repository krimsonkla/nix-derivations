#!/usr/bin/env bash
# knot install. Sourced by installPhase, never executed: makeWrapper and
# runHook are functions the build environment defines in the shell, and a
# separate process would not have them.
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

runHook preInstall

mkdir -p "$out/lib/knot" "$out/bin"
cp -r src resources bb.edn "$out/lib/knot/"

# knot needs nothing from its environment beyond the scrub: no variable to
# set, no executable to exec, so wrap_isolated is called without --set or
# --path and the wrapper is exactly the unsets plus the flags.
# shellcheck source=/dev/null # a store path, resolved at build time
source "$isolationWrapper"
wrap_isolated \
  --exe "$bbExe" \
  --name knot \
  --flags "--config $out/lib/knot/bb.edn --deps-root $out/lib/knot --classpath $out/lib/knot/src:$out/lib/knot/resources -m knot.main"

runHook postInstall
