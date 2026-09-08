#!/usr/bin/env bash
# Enumeration helpers shared by the guards. Each helper prints one item per
# line so callers can count and compare with sort/diff. Every helper returns
# non-zero when its enumeration itself fails, so a git or nix error is never
# read as "zero items".
set -euo pipefail
IFS=$'\n\t'

repo_root() { git rev-parse --show-toplevel; }

# Package directories under pkgs/by-name/<shard>/<name>/ (the filesystem side
# of the package-list check). Depth is exact: the shard directories are not
# packages, and a package nested one level deeper is not found.
list_package_dirs() {
  local root
  root=$(repo_root)
  find "$root/pkgs/by-name" -mindepth 2 -maxdepth 2 -type d -exec basename {} \; | sort
}

# Path of a package's directory under by-name, from its name alone.
package_dir() {
  printf '%s/pkgs/by-name/%s/%s' "$(repo_root)" "${1:0:2}" "$1"
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

# Hash-bearing ASSIGNMENT lines under pkgs/, as "<pkg> <attr>" rows, ONE ROW
# PER ASSIGNMENT (a multiset, so five outputHash lines in one package are five
# rows, and the registry must carry five matching rows).
# Assignment, not mention: a comment naming npmDepsHash is not a pin.
enumerate_hash_attrs() {
  local root
  root=$(repo_root)
  # No `\b`: git grep's ERE does not support it and silently matches nothing,
  # which is the empty-enumeration failure this guard exists to catch.
  git -C "$root" grep -nE '^[^#]*(^|[^A-Za-z_])(hash|sha256|outputHash|npmDepsHash|vendorHash|cargoHash)[[:space:]]*=' -- 'pkgs/by-name/*/*/*.nix' 'pkgs/by-name/*/*/**/*.nix' \
    | sed -E 's#^pkgs/by-name/[^/]+/([^/]+)/[^:]*:[0-9]+:[[:space:]]*([A-Za-z]+)[[:space:]]*=.*#\1 \2#' | sort
}

# rev assignment values under pkgs/, one per line.
enumerate_revs() {
  local root
  root=$(repo_root)
  git -C "$root" grep -hoE '(^|[^A-Za-z_])rev[[:space:]]*=[[:space:]]*"[^"]*"' -- 'pkgs/by-name/*/*/*.nix' \
    | sed -E 's#.*rev[[:space:]]*=[[:space:]]*"([^"]*)"#\1#' | sort -u
}
