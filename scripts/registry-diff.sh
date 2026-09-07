#!/usr/bin/env bash
# Verify registry rows whose package changed between BASE and HEAD with
# substitution disabled. If the range cannot be resolved, verify EVERY row:
# an empty range must never be green by construction.
set -euo pipefail
IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

log_info() { printf '[%s] %s\n' "$SCRIPT_NAME" "$*"; }
log_fatal() {
  printf '[%s] FATAL: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}
usage() { echo "usage: $SCRIPT_NAME <base-sha> <head-sha>"; }
cleanup() { :; }
trap cleanup EXIT
trap 'exit 1' INT TERM

declared_hash() {
  local root="$1" pkg="$2" attr="$3"
  git -C "$root" grep -hoE "${attr}[[:space:]]*=[[:space:]]*\"[^\"]*\"" -- "pkgs/$pkg/*.nix" | sed -E 's/.*"([^"]*)"/\1/'
}

# Re-fetch a fixed-output derivation and compare it to its declared hash.
# A first, ordinary build makes the output present (its dependencies such as
# curl may substitute, and the FOD itself may come from a cache); the second
# build with --rebuild then forces the fetcher to run again and errors if the
# result differs from what is in the store. --rebuild alone fails on a fresh
# runner ("outputs are not valid"), and a global substitute=false rebuilds the
# fetcher's own dependencies from source, so neither is used on its own.
refetch_and_verify() {
  local ref="$1"
  nix build --no-link "$ref"
  nix build --no-link --rebuild "$ref"
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  [[ $# -eq 2 ]] || {
    usage
    exit 64
  }
  local base="$1" head="$2" root mode="diff" changed_pkgs=""
  root="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel)"
  if [[ "$base" =~ ^0+$ ]] || ! git -C "$root" cat-file -e "${base}^{commit}" 2>/dev/null; then
    mode="all"
  else
    # A failing `git diff` must force mode=all, not yield an empty package
    # list: an empty list would verify zero rows and go green on the exact
    # error the fail-closed rule exists for. So the diff runs once, its exit
    # status is checked, and only then is the output parsed.
    local diff_out
    if ! diff_out="$(git -C "$root" diff --name-only "$base" "$head" -- pkgs/ tests/hash-registry.txt)"; then
      log_info "git diff failed; verifying every row"
      mode="all"
    else
      changed_pkgs="$(sed -nE 's#^pkgs/([^/]+)/.*#\1#p' <<<"$diff_out" | sort -u)"
      if grep -qx 'tests/hash-registry.txt' <<<"$diff_out"; then
        mode="all"
      fi
    fi
  fi
  log_info "mode=$mode base=$base head=$head"
  local n=0 pkg attr kind source
  while read -r pkg attr kind source; do
    if [[ "$mode" == "diff" ]] && ! grep -qxF "$pkg" <<<"$changed_pkgs"; then
      continue
    fi
    n=$((n + 1))
    case "$kind" in
      fetch) refetch_and_verify "$root#$pkg.src" ;;
      lockfile)
        case "$attr" in
          npmDepsHash)
            [[ "$(prefetch-npm-deps "$root/pkgs/$pkg/$source")" == "$(declared_hash "$root" "$pkg" npmDepsHash)" ]] || log_fatal "$pkg npmDepsHash drifted"
            ;;
          vendorHash) refetch_and_verify "$root#$pkg.goModules" ;;
          cargoHash) refetch_and_verify "$root#$pkg.cargoDeps" ;;
          *) log_fatal "unknown lockfile attr $attr" ;;
        esac
        ;;
      *) log_fatal "unknown kind $kind" ;;
    esac
  done < <(grep -vE '^[[:space:]]*(#|$)' "$root/tests/hash-registry.txt" | awk '{print $1, $2, $3, $4}' | tr ' ' '\t')
  log_info "registry-diff: $n rows verified (mode=$mode)"
}

main "$@"
