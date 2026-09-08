#!/usr/bin/env bats
# Labels name their subject, never their position. A test, heading or comment
# called by an ordinal or a section sign tells the reader nothing and goes
# stale the moment something is inserted before it. This guard sweeps every
# tracked text file for the positional forms and reports the size of the set
# it scanned, per the enumeration convention. It exempts itself: it must hold
# the shapes to detect them.

setup() {
  ROOT="$(git rev-parse --show-toplevel)"
  TEST_TMPDIR=$(mktemp -d -p "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR unset}")
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

POSITIONAL_RE='§|[Ss]ection[ -]?[0-9]|_section[0-9]|"[A-Z][0-9]+[:/ ]'

positional_hits() {
  grep -nE -- "$POSITIONAL_RE" "$@" 2>/dev/null || true
}

@test "named labels: no tracked file carries a positional label" {
  self="${BATS_TEST_FILENAME#"$ROOT"/}"
  mapfile -t files < <(git -C "$ROOT" ls-files | grep -vE '\.(lock|txt)$' | grep -vxF "$self")
  echo "named-labels: ${#files[@]} files scanned"
  [ "${#files[@]}" -gt 10 ]
  hits=$(cd "$ROOT" && positional_hits "${files[@]}")
  echo "$hits"
  [ -z "$hits" ]
}

@test "named labels: red -- a positional label is reported" {
  printf '# section 3 -- the registry\n_pass "§2 ok"\n' >"$TEST_TMPDIR/bad.sh"
  [ "$(positional_hits "$TEST_TMPDIR/bad.sh" | grep -c .)" -eq 2 ]
}

@test "named labels: green -- a subject-named label is not reported" {
  printf '# registry -- the registry\n_pass "charter: ok"\n' >"$TEST_TMPDIR/good.sh"
  [ -z "$(positional_hits "$TEST_TMPDIR/good.sh")" ]
}
