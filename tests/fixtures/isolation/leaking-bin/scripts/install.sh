#!/usr/bin/env bash
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

mkdir -p "$out/bin"
ln -s "$bbExe" "$out/bin/bb"
printf '#!/bin/sh\necho ok\n' > "$out/bin/leaking-bin"
chmod +x "$out/bin/leaking-bin"
