#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/bin" "$out/lib"
printf '%s\n' 'import sys' 'print("ok", len(sys.argv) - 1)' > "$out/lib/main.py"

# Deliberately bare: no scrub, so NIX_PYTHONPATH and PYTHONPATH stay in force
# and the hostile run imports the injected module.
makeWrapper "$pythonExe" "$out/bin/python-leak" --add-flags "$out/lib/main.py"
