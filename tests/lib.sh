#!/usr/bin/env bash
# Enumeration helpers shared by the guards. Each helper prints one item per
# line so callers can count and compare with sort/diff. Every helper returns
# non-zero when its enumeration itself fails, so a git or nix error is never
# read as "zero items".
set -euo pipefail
IFS=$'\n\t'

repo_root() { git rev-parse --show-toplevel; }

# Directories under pkgs/ (the filesystem side of the package-list check).
list_package_dirs() {
  local root
  root=$(repo_root)
  find "$root/pkgs" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

# Attribute names of the explicit list (the declared side). Inside a Nix
# sandbox `nix eval` is unavailable; the guard derivation exports DECLARED
# (a JSON list) and this helper prefers it when set.
list_declared_packages() {
  local root
  root=$(repo_root)
  if [[ -n "${DECLARED:-}" ]]; then
    printf '%s' "$DECLARED" | python3 -c 'import sys,json;[print(n) for n in sorted(json.load(sys.stdin))]'
  else
    nix eval --json --file "$root/pkgs/default.nix" --apply builtins.attrNames | python3 -c 'import sys,json;[print(n) for n in sorted(json.load(sys.stdin))]'
  fi
}

# Hash-bearing ASSIGNMENT lines under pkgs/, as "<pkg> <attr>" rows.
# Assignment, not mention: a comment naming npmDepsHash is not a pin.
enumerate_hash_attrs() {
  local root
  root=$(repo_root)
  git -C "$root" grep -nE '^[^#]*\b(hash|sha256|outputHash|npmDepsHash|vendorHash|cargoHash)[[:space:]]*=' -- 'pkgs/*/*.nix' 'pkgs/*/**/*.nix' \
    | sed -E 's#^pkgs/([^/]+)/[^:]*:[0-9]+:[[:space:]]*([A-Za-z]+)[[:space:]]*=.*#\1 \2#' | sort -u
}

# rev assignment values under pkgs/, one per line.
enumerate_revs() {
  local root
  root=$(repo_root)
  git -C "$root" grep -hoE '^[^#]*\brev[[:space:]]*=[[:space:]]*"[^"]*"' -- 'pkgs/*/*.nix' \
    | sed -E 's#.*rev[[:space:]]*=[[:space:]]*"([^"]*)"#\1#' | sort -u
}
