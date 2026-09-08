#!/usr/bin/env bats
# Isolation guard. Every package is one of three kinds: a cli whose runtime is
# private (bin/ holds exactly its commands, nothing propagates, the runtime it
# actually execs is the family it declares, and its smoke vectors print the
# same bytes under a hostile directory and environment); a library that
# lives inside its language set through the interpreter's fixpoint and never
# at top level; or an asset, data consumed by path, which ships its declared
# files and no bin/, propagates nothing, and is a top-level path. The facts arrive as a manifest the flake evaluated
# (ISOLATION_MANIFEST) and the family table (FAMILIES); outside a check
# derivation they are evaluated here. A runtime the table does not know is a
# named failure, never a pass. Counts are reported and pinned; ISOLATION_PINS
# overrides them for the fixture runs, and the report says which was used.

setup() {
  load lib.sh
  # shellcheck disable=SC1091 # sibling data file, resolved through repo_root at runtime
  source "$(repo_root)/tests/isolation-hostile.bash"
  ROOT=$(repo_root)
  if [[ -z "${ISOLATION_MANIFEST:-}" ]]; then
    system=$(nix eval --raw --impure --expr builtins.currentSystem)
    for p in $(list_declared_packages); do nix build --no-link "$ROOT#packages.$system.$p"; done
    ISOLATION_MANIFEST=$(nix eval --json "$ROOT#lib.isolationManifest.$system")
    FAMILIES=$(nix eval --json "$ROOT#lib.isolationFamilies")
  fi
  export ISOLATION_MANIFEST FAMILIES
  if [[ -n "${ISOLATION_PINS:-}" ]]; then
    IFS=' ' read -r PIN_N PIN_C PIN_L PIN_A PIN_F PIN_S <<<"$ISOLATION_PINS"
    PIN_SOURCE="ISOLATION_PINS override"
  else
    IFS=' ' read -r PIN_N PIN_C PIN_L PIN_A PIN_F PIN_S <<<"1 1 0 0 9 2"
    PIN_SOURCE="default"
  fi
  TEST_TMPDIR=$(mktemp -d -p "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR unset}")
}

teardown() { rm -rf "$TEST_TMPDIR"; }

rows() { python3 -c 'import sys,json;[print(json.dumps(r)) for r in json.loads(sys.argv[1])]' "$ISOLATION_MANIFEST"; }
field() { python3 -c 'import sys,json;v=json.loads(sys.argv[1]).get(sys.argv[2]);print(json.dumps(v) if isinstance(v,(list,dict)) else ("" if v is None else v))' "$1" "$2"; }
json_lines() { python3 -c 'import sys,json;v=json.loads(sys.argv[1]);assert isinstance(v,list);[print(x) for x in v]' "$1" 2>/dev/null; }

# family_of_store_path <path> -> the family whose match prefixes fit the
# store directory name (hash stripped: /nix/store/<hash>-babashka-1.13.219/bin/bb
# is judged by "babashka-1.13.219"), or "unknown:<name>" so the failure names
# what to add a row for.
family_of_store_path() {
  local name
  name=${1#/nix/store/}
  name=${name%%/*}
  name=${name#*-}
  python3 -c '
import sys, json
fams = json.loads(sys.argv[1]); name = sys.argv[2]
hits = sorted(f for f, v in fams.items() if any(name.startswith(m) for m in v["match"]))
print(hits[0] if hits else "unknown:" + name)' "$FAMILIES" "$name"
}

# detect_family <bin file> -> the family the command actually runs under. A
# script is classified by its shebang; a shell wrapper by the store path it
# execs (makeWrapper's shape, with or without an argv0 override); a binary
# wrapper (makeBinaryWrapper) by the first store path embedded in it; any
# other native executable is "none". Prints "unknown:<name>" for an
# interpreter the table lacks.
detect_family() {
  local f shebang target
  f=$(readlink -f "$1")
  if [[ "$(head -c 2 "$f")" != "#!" ]]; then
    target=$(grep -a -oE '/nix/store/[a-z0-9]{32}-[^/[:space:]"]+/bin/[^[:space:]"[:cntrl:]]+' "$f" | grep -vF "$(dirname "$f")" | head -1 || true)
    if [[ -n "$target" ]]; then
      family_of_store_path "$target"
    else
      echo none
    fi
    return
  fi
  shebang=$(head -n 1 "$f" | sed -E 's/^#! ?//; s/ .*//')
  case "$(basename "$shebang")" in
    bash | sh | dash | zsh)
      target=$(grep -oE '^exec( -a "?[^" ]+"?)? "?/nix/store/[^" ]+' "$f" | head -1 | sed -E 's/^exec( -a "?[^" ]+"?)? "?//')
      if [[ -n "$target" ]]; then
        family_of_store_path "$target"
      else
        echo shell
      fi
      ;;
    *) family_of_store_path "$shebang" ;;
  esac
}

@test "isolation: every package has a kind from the three-word vocabulary and the counts reconcile" {
  n=0
  c=0
  l=0
  a=0
  while read -r row; do
    n=$((n + 1))
    name=$(field "$row" name)
    kind=$(field "$row" kind)
    ikind=$(field "$row" index_kind)
    [ -n "$kind" ] || {
      echo "$name: no passthru.kind"
      return 1
    }
    [ "$kind" = "$ikind" ] || {
      echo "$name: passthru.kind $kind but the index says $ikind"
      return 1
    }
    case "$kind" in
      cli) c=$((c + 1)) ;;
      library) l=$((l + 1)) ;;
      asset) a=$((a + 1)) ;;
      *)
        echo "$name: kind '$kind' is not cli, library or asset"
        return 1
        ;;
    esac
  done < <(rows)
  echo "isolation: $n packages, $c cli, $l library, $a asset (pins: $PIN_SOURCE)"
  [ "$n" -eq $((c + l + a)) ]
  [ "$n" -eq "$PIN_N" ] && [ "$c" -eq "$PIN_C" ] && [ "$l" -eq "$PIN_L" ] && [ "$a" -eq "$PIN_A" ]
}

@test "isolation: the hostile table, the set table and the fixture directories name the same families" {
  nix_fams=$(python3 -c 'import sys,json;[print(k) for k in sorted(json.loads(sys.argv[1]))]' "$FAMILIES")
  diff <(printf '%s\n' "$nix_fams") <(hostile_families | sort)
  diff <(printf '%s\n' "$nix_fams") <(find "$ROOT/tests/fixtures/isolation-hostile" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  n=$(printf '%s\n' "$nix_fams" | grep -c .)
  echo "isolation: $n runtime families (pins: $PIN_SOURCE)"
  [ "$n" -eq "$PIN_F" ]
}

@test "isolation: every cli owns exactly its bins, runs under its declared family, propagates nothing, and its smoke vectors survive a hostile run" {
  cmds=0
  while read -r row; do
    [ "$(field "$row" kind)" = cli ] || continue
    name=$(field "$row" name)
    out=$(field "$row" out)
    runtime=$(field "$row" runtime)
    bins=$(field "$row" bins)
    smoke=$(field "$row" smoke)
    [ -n "$bins" ] && [ -n "$runtime" ] && [ -n "$smoke" ] || {
      echo "$name: a cli declares passthru.bins, passthru.smoke and passthru.runtime (missing subject)"
      return 1
    }
    hostile_families | grep -qxF "$runtime" || {
      echo "$name: runtime '$runtime' is not a known family; add a row to lib/isolation.nix and tests/isolation-hostile.bash"
      return 1
    }
    diff <(find "$out/bin" -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | sort) <(json_lines "$bins" | sort) || {
      echo "$name: bin/ is not exactly passthru.bins (leaking bin)"
      return 1
    }
    for b in $(json_lines "$bins"); do
      detected=$(detect_family "$out/bin/$b")
      [ "$detected" = "$runtime" ] || {
        echo "$name: $b runs under '$detected' but passthru.runtime says '$runtime' (a family the table lacks needs a row; a wrong declaration needs correcting)"
        return 1
      }
    done
    for ch in propagated_build_inputs propagated_native_build_inputs propagated_user_env_pkgs; do
      [ "$(field "$row" $ch)" = "[]" ] || {
        echo "$name: $ch is not empty"
        return 1
      }
    done
    if [ -e "$out/nix-support/setup-hook" ] || ls "$out"/nix-support/propagated-* >/dev/null 2>&1; then
      echo "$name: nix-support carries a setup hook or propagation file"
      return 1
    fi
    hdir="$ROOT/tests/fixtures/isolation-hostile/$runtime"
    hcopy="$TEST_TMPDIR/hostile-$name"
    mkdir -p "$hcopy"
    cp -r "$hdir/." "$hcopy/"
    mapfile -t henv < <(hostile_env "$runtime" "$hcopy")
    # lib.sh sets IFS to newline and tab, so the split here is explicit: with
    # the default inherited, cmd swallowed the whole row and both runs failed
    # identically as "command not found", which compared equal and passed.
    while IFS=' ' read -r cmd vec; do
      cmds=$((cmds + 1))
      [ -n "$cmd" ] && [ -n "$vec" ] || {
        echo "$name: malformed smoke row '$cmd $vec'"
        return 1
      }
      mapfile -t args < <(json_lines "$vec") || {
        echo "$name: smoke vector '$vec' is not a JSON list"
        return 1
      }
      [ -x "$out/bin/$cmd" ] || {
        echo "$name: smoke command '$cmd' does not resolve under $out/bin"
        return 1
      }
      clean=$(cd "$TEST_TMPDIR" && env -i HOME="$TEST_TMPDIR" PATH="$out/bin" "$cmd" ${args[@]+"${args[@]}"} 2>&1; echo "exit=$?")
      [[ "$clean" != *"exit=12"[67] ]] || {
        echo "$name: $cmd did not run cleanly: $clean"
        return 1
      }
      hostile=$(cd "$hcopy" && env -i HOME="$TEST_TMPDIR" PATH="$out/bin" ${henv[@]+"${henv[@]}"} "$cmd" ${args[@]+"${args[@]}"} 2>&1; echo "exit=$?")
      [ "$clean" = "$hostile" ] || {
        echo "$name: $cmd $vec differs under the $runtime hostile run"
        printf -- '--- clean\n%s\n--- hostile\n%s\n' "$clean" "$hostile"
        return 1
      }
      if grep -q HIJACKED <<<"$clean$hostile"; then
        echo "$name: hijack marker in output"
        return 1
      fi
    done < <(python3 -c 'import sys,json;[print(c, json.dumps(v)) for c,vs in json.loads(sys.argv[1]).items() for v in vs]' "$smoke")
  done < <(rows)
  echo "isolation: $cmds smoke vectors unchanged under a hostile cwd and environment (pins: $PIN_SOURCE)"
  [ "$cmds" -eq "$PIN_S" ]
}

@test "isolation: every library sits in its declared set through the fixpoint and nowhere else" {
  n=0
  while read -r row; do
    [ "$(field "$row" kind)" = library ] || continue
    n=$((n + 1))
    name=$(field "$row" name)
    set=$(field "$row" set)
    iset=$(field "$row" index_set)
    out=$(field "$row" out)
    [ -n "$set" ] || {
      echo "$name: a library declares passthru.set (missing subject)"
      return 1
    }
    python3 -c 'import sys,json;f=json.loads(sys.argv[1]);sys.exit(0 if any(v.get("set")==sys.argv[2] for v in f.values()) else 1)' "$FAMILIES" "$set" || {
      echo "$name: no family provides the set $set (wrong set)"
      return 1
    }
    [ "$set" = "$iset" ] || {
      echo "$name: passthru.set $set but the index says $iset"
      return 1
    }
    [ ! -e "$out/bin" ] || {
      echo "$name: a library ships bin/"
      return 1
    }
    [ "$(field "$row" top_level_absent)" = True ] || {
      echo "$name: present at top level"
      return 1
    }
    [ "$(field "$row" set_present)" = True ] || {
      echo "$name: absent from $set"
      return 1
    }
    [ "$(field "$row" fixpoint_equal)" = True ] || {
      echo "$name: $set.$name is not the interpreter's own $name (fixpoint broken)"
      return 1
    }
  done < <(rows)
  echo "isolation: $n libraries checked at their set (pins: $PIN_SOURCE)"
  [ "$n" -eq "$PIN_L" ]
}

@test "isolation: every asset ships its declared files, no bin/, propagates nothing, and is a top-level path" {
  n=0
  while read -r row; do
    [ "$(field "$row" kind)" = asset ] || continue
    n=$((n + 1))
    name=$(field "$row" name)
    out=$(field "$row" out)
    files=$(field "$row" files)
    [ -n "$files" ] && [ "$files" != "[]" ] || {
      echo "$name: an asset declares passthru.files, the paths under \$out that prove its layout (missing subject)"
      return 1
    }
    for f in $(json_lines "$files"); do
      [ -e "$out/$f" ] || {
        echo "$name: declared file $f is absent from the output"
        return 1
      }
    done
    [ ! -e "$out/bin" ] || {
      echo "$name: an asset ships bin/ (leaking bin)"
      return 1
    }
    for ch in propagated_build_inputs propagated_native_build_inputs propagated_user_env_pkgs; do
      [ "$(field "$row" $ch)" = "[]" ] || {
        echo "$name: $ch is not empty"
        return 1
      }
    done
    if [ -e "$out/nix-support/setup-hook" ] || ls "$out"/nix-support/propagated-* >/dev/null 2>&1; then
      echo "$name: nix-support carries a setup hook or propagation file"
      return 1
    fi
    [ "$(field "$row" top_level_absent)" = False ] || {
      echo "$name: an asset is a top-level path and is absent"
      return 1
    }
  done < <(rows)
  echo "isolation: $n assets checked by their declared files (pins: $PIN_SOURCE)"
  [ "$n" -eq "$PIN_A" ]
}
