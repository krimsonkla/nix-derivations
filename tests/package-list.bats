#!/usr/bin/env bats
# Package-list guard: the explicit attrset in pkgs/default.nix and the
# directories under pkgs/ must be the same set, in both directions, and the
# set must be non-empty. A readDir-derived list would make both sides of this
# count come from one walk; the explicit list is what makes the assertion
# able to fail.

setup() { load lib.sh; }

@test "package-list: directories and declared list agree both ways and are non-empty" {
  dirs=$(list_package_dirs)
  declared=$(list_declared_packages)
  n_dirs=$(printf '%s\n' "$dirs" | grep -c . || true)
  n_declared=$(printf '%s\n' "$declared" | grep -c . || true)
  echo "package-list: $n_dirs directories, $n_declared listed"
  [ "$n_dirs" -gt 0 ]
  diff <(printf '%s\n' "$dirs") <(printf '%s\n' "$declared")
}

@test "package-list: count pin" {
  # Bump this literal when a package is added or removed. It is the half that
  # makes a silently shrunken enumeration red.
  [ "$(list_declared_packages | grep -c .)" -eq 1 ]
}

@test "package-list: every package README carries the five required headings" {
  root=$(repo_root)
  for p in $(list_declared_packages); do
    for h in "## Upstream" "## Pinned rev" "## Why here, not nixpkgs" "## Bump procedure" "## Patches"; do
      grep -qxF "$h" "$root/pkgs/$p/README.md" || {
        echo "$p/README.md missing '$h'"
        return 1
      }
    done
  done
}
