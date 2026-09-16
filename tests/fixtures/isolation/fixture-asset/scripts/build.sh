#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/refs" "$out/blobs"
echo 0000 > "$out/refs/main"
echo data > "$out/blobs/0000"
