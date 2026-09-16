#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/refs" "$out/bin"
echo 0000 > "$out/refs/main"
printf '#!/bin/sh\necho leak\n' > "$out/bin/asset-with-bin"
chmod +x "$out/bin/asset-with-bin"
