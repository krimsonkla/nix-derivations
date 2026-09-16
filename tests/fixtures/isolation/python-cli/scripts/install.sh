#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/bin" "$out/lib"
printf '%s\n' 'import sys' 'print("ok", len(sys.argv) - 1)' > "$out/lib/main.py"

# The point of this fixture: the wrapper is built by the shared helper, so the
# python family's scrub list comes from the family table rather than from a
# copy here. python-leak is the same program wrapped without it.
# shellcheck source=/dev/null # a store path, resolved at build time
source "$isolationWrapper"
wrap_isolated \
  --exe "$pythonExe" \
  --name python-cli \
  --flags "$out/lib/main.py"
