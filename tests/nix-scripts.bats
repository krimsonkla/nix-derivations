#!/usr/bin/env bats
# No-embedded-shell guard. A package expression declares a package; it does
# not carry the shell that builds one. Every phase is a single
# `source ${./scripts/<name>.sh}` and the script lives beside the expression,
# where shellcheck reads it and bash quoting means what bash says rather than
# what survives Nix string escaping. The scanner reports the size of the set
# it validated and the counts are pinned, per the enumeration convention; the
# red tests hold it honest on files written here, so a scanner that stopped
# matching anything cannot pass as clean.

# The red and green fixtures below are Nix source written as literal text, so
# their `$out` and `${./scripts/...}` must reach the file unexpanded. Single
# quotes are the point, not an oversight.
# shellcheck disable=SC2016

setup() {
  load lib.sh
  ROOT=$(repo_root)
  SCAN="$ROOT/scripts/scan-nix-shell.py"
  TEST_TMPDIR=$(mktemp -d -p "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR unset}")
}

teardown() { rm -rf "$TEST_TMPDIR"; }

@test "nix-scripts: no package expression embeds shell" {
  mapfile -t files < <(list_package_expressions)
  echo "nix-scripts: ${#files[@]} expressions"
  [ "${#files[@]}" -gt 0 ]
  run python3 "$SCAN" "${files[@]}"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "nix-scripts: count pin" {
  # Bump when a package or an isolation fixture is added or removed. It is the
  # half that makes a silently shrunken enumeration red.
  [ "$(list_package_expressions | grep -c .)" -eq 13 ]
  [ "$(list_package_scripts | grep -c .)" -eq 13 ]
}

@test "nix-scripts: every externalized script is tracked and executable-shaped" {
  n=0
  for s in $(list_package_scripts); do
    n=$((n + 1))
    head -n 1 "$ROOT/$s" | grep -qE '^#!/usr/bin/env bash$' || {
      echo "$s: first line is not a bash shebang"
      return 1
    }
  done
  echo "nix-scripts: $n scripts carry a bash shebang"
  [ "$n" -gt 0 ]
}

@test "nix-scripts: red -- an indented string is reported" {
  printf '%s\n' '{stdenvNoCC}:' 'stdenvNoCC.mkDerivation {' "  installPhase = ''" \
    '    mkdir -p $out/bin' "  '';" '}' >"$TEST_TMPDIR/bad.nix"
  run python3 "$SCAN" "$TEST_TMPDIR/bad.nix"
  [ "$status" -eq 1 ]
  [[ "$output" == *"indented-string"* ]]
}

@test "nix-scripts: red -- a one-line shell phase is reported" {
  printf '%s\n' '{stdenvNoCC}:' 'stdenvNoCC.mkDerivation {' \
    '  installPhase = "mkdir -p $out/bin";' '}' >"$TEST_TMPDIR/bad.nix"
  run python3 "$SCAN" "$TEST_TMPDIR/bad.nix"
  [ "$status" -eq 1 ]
  [[ "$output" == *"inline-shell"* ]]
}

@test "nix-scripts: red -- a phase naming a script that is not there is reported" {
  printf '%s\n' '{stdenvNoCC}:' 'stdenvNoCC.mkDerivation {' \
    '  installPhase = "source ${./scripts/absent.sh}";' '}' >"$TEST_TMPDIR/bad.nix"
  run python3 "$SCAN" "$TEST_TMPDIR/bad.nix"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-script"* ]]
}

@test "nix-scripts: red -- no argument is a usage error" {
  run python3 "$SCAN"
  [ "$status" -eq 64 ]
}

@test "nix-scripts: green -- an externalized phase is not reported" {
  mkdir -p "$TEST_TMPDIR/scripts"
  printf '#!/usr/bin/env bash\nmkdir -p "$out/bin"\n' >"$TEST_TMPDIR/scripts/install.sh"
  printf '%s\n' '{stdenvNoCC}:' 'stdenvNoCC.mkDerivation {' \
    '  installPhase = "source ${./scripts/install.sh}";' '}' >"$TEST_TMPDIR/good.nix"
  run python3 "$SCAN" "$TEST_TMPDIR/good.nix"
  [ "$status" -eq 0 ]
}
