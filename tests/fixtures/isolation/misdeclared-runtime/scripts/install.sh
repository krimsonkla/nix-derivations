#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/bin"
makeWrapper "$bbExe" "$out/bin/misdeclared-runtime" --add-flags "-e '(println \"ok\")'"
