#!/usr/bin/env bats
# Charter guard: the README, CONTRIBUTING and LICENSE text carries acceptance
# criteria of its own (visibility decision, conventions, license scope), so it
# is verified rather than assumed. Counts are printed and pinned per the
# enumeration convention.

setup() {
  ROOT="$(git rev-parse --show-toplevel)"
}

@test "charter: README carries every required section" {
  for h in "## What this is" "## Consuming" "## Why public" "## Adding a package" "## CI" "## Residual risks"; do
    grep -qxF "$h" "$ROOT/README.md" || {
      echo "README missing '$h'"
      return 1
    }
  done
  grep -qF "krimsonkla-nixpkgs.cachix.org-1:9WHsyDVPF07aDDPjysKKmovp4LxPztFlSPV2Vj0lZgk=" "$ROOT/README.md"
  grep -qF "reopens" "$ROOT/README.md"
}

@test "charter: README residual-risks section has six bullets" {
  n=$(awk '/^## Residual risks/{f=1;next} /^## /{f=0} f && /^- /{c++} END{print c+0}' "$ROOT/README.md")
  echo "charter: $n residual bullets"
  [ "$n" -eq 6 ]
}

@test "charter: CONTRIBUTING lists the twelve conventions and the enforcement map" {
  # Count numbered items only inside the Conventions section; the Bumping
  # section is numbered too and must not inflate this. Two-digit numbers
  # count: a single-digit class here once reported nine while eleven were
  # listed, which is the silently-short enumeration this pin exists to catch.
  n=$(awk '/^## Conventions/{f=1;next} /^## /{f=0} f && /^[0-9]+\. /{c++} END{print c+0}' "$ROOT/CONTRIBUTING.md")
  echo "charter: $n conventions"
  # Twelve since the package-kind convention; the pin moves with the list.
  [ "$n" -eq 12 ]
  grep -qF "written-only" "$ROOT/CONTRIBUTING.md"
}

@test "charter: LICENSE scopes MIT to packaging expressions" {
  grep -qF "packaging expressions in this repository only" "$ROOT/LICENSE"
}
