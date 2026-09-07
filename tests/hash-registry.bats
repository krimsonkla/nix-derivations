#!/usr/bin/env bats
# Hash-registry guard. Test A enumerates every hash-bearing assignment under
# pkgs/ and pins it against the hand-maintained registry in both directions.
# Test B verifies lockfile-kind rows against their lockfile. Test C is
# reachability only: a fixed-output build that substitutes never re-fetches,
# so hash-versus-source verification for fetch-kind rows lives in the
# non-substituting CI lanes, not here. Test D rejects placeholders.

setup() {
  load lib.sh
  REG="$(repo_root)/tests/hash-registry.txt"
}

registry_rows() { grep -vE '^[[:space:]]*(#|$)' "$REG" | awk '{print $1, $2, $3, $4}'; }

@test "A: enumerated hash attributes equal registry rows both ways, non-empty" {
  enumerated=$(enumerate_hash_attrs)
  registered=$(registry_rows | awk '{print $1, $2}' | sort -u)
  n_e=$(printf '%s\n' "$enumerated" | grep -c . || true)
  n_r=$(printf '%s\n' "$registered" | grep -c . || true)
  echo "hash-registry: $n_e enumerated, $n_r registered"
  [ "$n_e" -gt 0 ]
  diff <(printf '%s\n' "$enumerated") <(printf '%s\n' "$registered")
}

@test "A: count pin" {
  [ "$(registry_rows | grep -c .)" -eq 1 ]
}

@test "B: lockfile rows verified" {
  n=0
  while read -r pkg attr kind source; do
    [ "$kind" = lockfile ] || continue
    n=$((n + 1))
    case "$attr" in
      npmDepsHash)
        declared=$(git -C "$(repo_root)" grep -hoE 'npmDepsHash[[:space:]]*=[[:space:]]*"[^"]*"' -- "pkgs/$pkg/*.nix" | sed -E 's/.*"([^"]*)"/\1/')
        computed=$(prefetch-npm-deps "$(repo_root)/pkgs/$pkg/$source")
        [ "$declared" = "$computed" ] || {
          echo "$pkg npmDepsHash $declared != $computed"
          return 1
        }
        ;;
      vendorHash) nix build --rebuild --option substitute false ".#$pkg.goModules" ;;
      cargoHash) nix build --rebuild --option substitute false ".#$pkg.cargoDeps" ;;
      *)
        echo "unknown lockfile attr $attr"
        return 1
        ;;
    esac
  done < <(registry_rows)
  echo "hash-registry: $n lockfile rows verified"
}

@test "B: lockfile count pin" {
  # Day one: zero lockfile rows. This literal is bumped by the first lockfile
  # package (the npm migration), which is where Test B first goes red/green.
  [ "$(registry_rows | awk '$3=="lockfile"' | grep -c . || true)" -eq 0 ]
}

@test "C: every fetch row's package is a check attribute (reachability only)" {
  if [[ -n "${CHECK_ATTRS:-}" ]]; then
    checks="$CHECK_ATTRS"
  else
    checks=$(nix eval --json ".#checks.$(nix eval --raw --impure --expr builtins.currentSystem)" --apply builtins.attrNames)
  fi
  while read -r pkg attr kind source; do
    [ "$kind" = fetch ] || continue
    printf '%s' "$checks" | grep -q "\"$pkg\"" || {
      echo "$pkg not in checks"
      return 1
    }
  done < <(registry_rows)
}

@test "D: no placeholder hashes, every rev is a full sha" {
  root=$(repo_root)
  # A bare `!` does not fail a bats test, so each placeholder pattern is an
  # explicit if/return.
  for pat in 'lib\.fakeHash|(hash|sha256|outputHash|npmDepsHash|vendorHash|cargoHash)[[:space:]]*=[[:space:]]*""' 'sha256-A{43}=' '0{52}'; do
    if git -C "$root" grep -nE "$pat" -- 'pkgs/*/*.nix'; then
      echo "placeholder hash matched pattern: $pat"
      return 1
    fi
  done
  # Pin the rev enumeration to the registry: every fetchFromGitHub row carries
  # exactly one rev, so an empty enumeration cannot pass this loop vacuously.
  n_revs=$(enumerate_revs | grep -c . || true)
  n_gh=$(registry_rows | awk '$3=="fetch" && $4=="fetchFromGitHub"' | grep -c . || true)
  echo "hash-registry: $n_revs revs enumerated, $n_gh fetchFromGitHub rows"
  [ "$n_revs" -eq "$n_gh" ]
  for r in $(enumerate_revs); do
    [[ "$r" =~ ^[0-9a-f]{40}$ ]] || {
      echo "rev not a full sha: $r"
      return 1
    }
  done
}
