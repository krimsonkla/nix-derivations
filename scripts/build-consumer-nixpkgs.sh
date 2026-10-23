#!/usr/bin/env bash
# Build, or with --substitute-only prove from the cache, every package against
# each consumer nixpkgs in a refs file. The refs file is the stdout of
# `scripts/consumer-nixpkgs.py provenance consumer-nixpkgs.txt`: callers never
# hand this script the raw list, so every value here passed the allowlist and
# the upstream check first. Packages are built for the current system only.
set -euo pipefail
shopt -s inherit_errexit
IFS=$'\n\t'
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

usage() {
  echo "usage: $SCRIPT_NAME [--substitute-only] <refs-file>" >&2
  exit 64
}

fail() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

substitute_only=0
if [[ "${1:-}" == --substitute-only ]]; then
  substitute_only=1
  shift
fi
[[ $# -eq 1 ]] || usage
refs="$1"
[[ -s "$refs" ]] || fail "refs file '$refs' is missing or empty; run consumer-nixpkgs.py provenance first"

system=$(nix eval --raw --impure --expr builtins.currentSystem)
count=0
while IFS=' ' read -r label ref; do
  [[ -n "$label" ]] || continue
  [[ "$ref" =~ ^github:[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/[0-9a-f]{40}$ ]] || fail "$label: ref '$ref' is not a validated flake ref"
  override=(--override-input nixpkgs "$ref")
  mapfile -t attrs < <(nix eval --raw "${override[@]}" ".#packages.$system" \
    --apply 'ps: builtins.concatStringsSep "\n" (map (n: ".#" + n) (builtins.attrNames ps))')
  [[ ${#attrs[@]} -gt 0 ]] || fail "$label: no packages evaluated for $system"
  # Force full instantiation first, as the publish workflow does for its own
  # nixpkgs: devenv-nixpkgs applies its patches at evaluation time, and that
  # build must not land inside a --max-jobs 0 run. The ${n} is Nix
  # interpolation, so the single quotes are deliberate.
  # shellcheck disable=SC2016
  nix eval --raw "${override[@]}" ".#packages.$system" \
    --apply 'ps: builtins.concatStringsSep "\n" (map (n: ps.${n}.drvPath) (builtins.attrNames ps))' >/dev/null ||
    fail "$label: instantiation failed under $ref"
  build=(nix build --no-link --print-out-paths --print-build-logs "${override[@]}")
  if [[ $substitute_only -eq 1 ]]; then
    build+=(--max-jobs 0)
    verb=substituted
  else
    verb=built
  fi
  "${build[@]}" "${attrs[@]}" || fail "$label: packages failed to $([[ $substitute_only -eq 1 ]] && echo substitute || echo build) under $ref"
  printf 'consumer-nixpkgs: %s %d packages %s on %s\n' "$label" "${#attrs[@]}" "$verb" "$system"
  count=$((count + 1))
done <"$refs"
[[ $count -gt 0 ]] || fail "no refs read from '$refs'"
printf 'consumer-nixpkgs: %d refs %s on %s\n' "$count" "$([[ $substitute_only -eq 1 ]] && echo proven || echo built)" "$system"
