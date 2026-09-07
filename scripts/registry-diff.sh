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
    changed_pkgs="$(git -C "$root" diff --name-only "$base" "$head" -- pkgs/ | sed -nE 's#^pkgs/([^/]+)/.*#\1#p' | sort -u || true)"
    if git -C "$root" diff --name-only "$base" "$head" -- tests/hash-registry.txt | grep -q .; then
      mode="all"
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
      fetch) nix build --rebuild --option substitute false "$root#$pkg.src" ;;
      lockfile)
        case "$attr" in
          npmDepsHash)
            [[ "$(prefetch-npm-deps "$root/pkgs/$pkg/$source")" == "$(declared_hash "$root" "$pkg" npmDepsHash)" ]] || log_fatal "$pkg npmDepsHash drifted"
            ;;
          vendorHash) nix build --rebuild --option substitute false "$root#$pkg.goModules" ;;
          cargoHash) nix build --rebuild --option substitute false "$root#$pkg.cargoDeps" ;;
          *) log_fatal "unknown lockfile attr $attr" ;;
        esac
        ;;
      *) log_fatal "unknown kind $kind" ;;
    esac
  done < <(grep -vE '^[[:space:]]*(#|$)' "$root/tests/hash-registry.txt" | awk '{print $1, $2, $3, $4}' | tr ' ' '\t')
  log_info "registry-diff: $n rows verified (mode=$mode)"
}

main "$@"
