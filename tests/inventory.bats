#!/usr/bin/env bats
# Inventory guard: the scanner's counts and names are pinned against a
# fixture checkout it cannot have seen, per the enumeration convention. The
# fixture files put pname and version on their own lines and any enclosed
# fetcher on a later, deeper line, because the parser is line-anchored and
# the enclosure rule compares indents.

setup() {
  ROOT="$(git rev-parse --show-toplevel)"
  SCAN="$ROOT/scripts/inventory-derivations.py"
  FIX=$(mktemp -d -p "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR unset}")
  _fixture "$FIX/repo"
}

teardown() {
  rm -rf "$FIX"
}

_fixture() {
  local d="$1"
  mkdir -p "$d"
  cat >"$d/a.nix" <<'NIX'
{ buildPythonPackage, fetchPypi }:
buildPythonPackage rec {
  pname = "alpha";
  version = "1.2";
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-AAAA";
  };
}
NIX
  cat >"$d/b.nix" <<'NIX'
{ buildNpmPackage }:
buildNpmPackage {
  pname = "beta";
  version = "0.1";
  npmDepsHash = "sha256-BBBB";
}
NIX
  cat >"$d/c.nix" <<'NIX'
final: prev: {
  gamma = prev.gamma.overrideAttrs (o: {
    doCheck = false;
  });
}
NIX
  cat >"$d/d.nix" <<'NIX'
{ fetchurl }:
fetchurl {
  url = "https://example.invalid/delta.tar.gz";
  hash = "sha256-DDDD";
}
NIX
  cat >"$d/e.nix" <<'NIX'
{ buildPythonPackage }:
let
  pname = "epsilon";
  version = "3";
in
buildPythonPackage {
  inherit pname version;
  src = ./.;
}
NIX
  cat >"$d/f.nix" <<'NIX'
{
  buildPythonPackage,
  fetchPypi,
  ...
}: {
  fetchPypi = fetchPypi;
}
NIX
  git -C "$d" init -q
  git -C "$d" -c user.email=t@localhost -c user.name=t add -A
  git -C "$d" -c user.email=t@localhost -c user.name=t commit -qm fixture
}

KINDS="buildNpmPackage,buildGoModule,buildPythonPackage,buildPythonApplication,mkDerivation,overrideAttrs,overridePythonAttrs,fetchFromGitHub,fetchFromGitLab,fetchurl,fetchzip,fetchgit,fetchPypi,fetchTarball"

@test "inventory: kinds line names every recognised builder and fetcher" {
  run python3 "$SCAN" "$FIX/repo"
  [ "$status" -eq 0 ]
  first="${lines[0]}"
  [ "$first" = "inventory-kinds: $KINDS" ]
  n=$(tr ',' '\n' <<<"${first#inventory-kinds: }" | grep -c .)
  echo "inventory: $n kinds"
  [ "$n" -eq 14 ]
}

@test "inventory: the fixture yields the pinned count and every name" {
  run python3 "$SCAN" "$FIX/repo"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "inventory: 1 checkouts scanned, 5 derivations found" ]
  rows=$(printf '%s\n' "${lines[@]}" | awk -F'\t' 'NR>2 && !/^inventory:/')
  [ "$(grep -c . <<<"$rows")" -eq 5 ]
  grep -qE $'a\\.nix:[0-9]+\tbuildPythonPackage\talpha\t1\\.2\t' <<<"$rows"
  grep -qE $'b\\.nix:[0-9]+\tbuildNpmPackage\tbeta\t0\\.1\t' <<<"$rows"
  grep -qE $'c\\.nix:[0-9]+\toverrideAttrs\tgamma\t\t' <<<"$rows"
  grep -qE $'d\\.nix:[0-9]+\tfetchurl\tdelta\\.tar\\.gz\t\t' <<<"$rows"
  grep -qE $'e\\.nix:[0-9]+\tbuildPythonPackage\tepsilon\t3\t' <<<"$rows"
  if grep -q 'f\.nix' <<<"$rows"; then false; fi
  if grep -q 'fetchPypi' <<<"$rows"; then false; fi
}

@test "inventory: red -- a directory that is not a checkout exits 2 naming it" {
  mkdir -p "$FIX/plain"
  run python3 "$SCAN" "$FIX/plain"
  [ "$status" -eq 2 ]
  [[ "$output" == *"$FIX/plain"* ]]
}

@test "inventory: red -- no arguments is a usage error" {
  run python3 "$SCAN"
  [ "$status" -eq 64 ]
}
