#!/usr/bin/env bash
# clj-surgeon install. Sourced by installPhase, never executed: makeWrapper,
# patchShebangs and runHook are functions the build environment defines in the
# shell, and a separate process would not have them.
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

runHook preInstall

mkdir -p "$out/lib/clj-surgeon" "$out/bin"
cp -r src resources bb.edn "$out/lib/clj-surgeon/"
chmod -R u+w "$out/lib/clj-surgeon"

# The admission gate is exec'd by the tool, so it needs its mode and an
# interpreter that resolves under the closed PATH the wrapper sets.
chmod +x "$out/lib/clj-surgeon/resources/clj-kondo-admission.py"
patchShebangs --host "$out/lib/clj-surgeon/resources/clj-kondo-admission.py"

# The scrub list is the family table's, exported by lib/isolation.nix as
# $isolationScrub; wrap_isolated turns it, the variables this tool reads and
# the closed PATH into one makeWrapper call, so no package writes one.
# shellcheck source=/dev/null # a store path, resolved at build time
source "$isolationWrapper"
wrap_isolated \
  --exe "$bbExe" \
  --name clj-surgeon \
  --set "CLJ_SURGEON_CLJ_KONDO_ADMISSION=$out/lib/clj-surgeon/resources/clj-kondo-admission.py" \
  --path "$isolationBinPath" \
  --flags "--config $out/lib/clj-surgeon/bb.edn --deps-root $out/lib/clj-surgeon --classpath $out/lib/clj-surgeon/src:$out/lib/clj-surgeon/resources -m clj-surgeon.core"

runHook postInstall
