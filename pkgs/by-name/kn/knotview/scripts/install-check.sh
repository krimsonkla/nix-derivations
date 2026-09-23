#!/usr/bin/env bash
# knotview install check. Four moves: every module imports, the packaged
# version matches what upstream says it is, the declared command answers under
# an empty environment, and its answers are byte-identical from a hostile
# directory and environment.
#
# Sourced by installCheckPhase, never executed: it needs the build shell's
# runHook and the variables the derivation exports.
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

runHook preInstallCheck

HOME=$(mktemp -d)
export HOME

# Every module loads under this python: a dependency missing from the closure
# fails here with the name of the module that wanted it, not later on the page
# that first reaches it.
"$pythonExe" "$importAll" "$out/lib/knotview" knotview

# The version this derivation claims, against the version upstream's own
# metadata states, read from the source so a bump that forgets one of the two
# is caught here. knotview has no --version flag to ask instead.
declared=$(sed -nE 's/^version = "([^"]+)"$/\1/p' pyproject.toml | head -n 1)
[ "$declared" = "$version" ] || {
  echo "pyproject.toml says version $declared, the derivation says $version"
  exit 1
}
echo "version: $version matches upstream's own metadata"

# The command a consumer's shell is promised, under an empty environment: a
# wrapper that only works while the build's own variables (out, src) are set
# must fail here, not in a consumer. The refusal vector exits non-zero by
# design, so its status is not the build's.
clean=(env -i "HOME=$HOME" "PATH=$out/bin")
empty=$(mktemp -d)
help=$(cd "$empty" && "${clean[@]}" knotview --help)
grep -q 'usage: knotview' <<<"$help" || {
  echo "knotview --help printed: $help"
  exit 1
}
refusal=$(cd "$empty" && "${clean[@]}" knotview nosuchproject 2>&1 || true)
grep -q "no project is saved as 'nosuchproject'" <<<"$refusal" || {
  echo "knotview nosuchproject printed: $refusal"
  exit 1
}

# Isolation: the same command from a directory holding the files this python
# would execute if it read the working directory, and under the variables the
# family honours, byte-identical, no marker. The hostile files are written
# here rather than taken from tests/, so the package's hash depends on nothing
# outside pkgs/ and lib/. NIX_PYTHONPATH is the one that matters: nixpkgs'
# sitecustomize feeds it to site.addsitedir, which executes the .pth file.
h=$(mktemp -d)
printf '%s\n' 'print("HIJACKED-BY-CWD")' > "$h/sitecustomize.py"
printf '%s\n' 'print("HIJACKED-BY-CWD")' > "$h/hijack.py"
printf '%s\n' 'import hijack' > "$h/hijack.pth"
hostile=(
  "PYTHONPATH=$h"
  "NIX_PYTHONPATH=$h"
  "PYTHONSTARTUP=$h/sitecustomize.py"
  "PYTHONUSERBASE=$h"
)
hh=$(cd "$h" && "${clean[@]}" "${hostile[@]}" knotview --help)
hr=$(cd "$h" && "${clean[@]}" "${hostile[@]}" knotview nosuchproject 2>&1 || true)
[ "$hh" = "$help" ] && [ "$hr" = "$refusal" ] \
  || { echo "output changed under a hostile cwd or environment"; exit 1; }
if grep -q HIJACKED <<<"$hh$hr"; then echo "hijack marker in output"; exit 1; fi
echo "isolation: 2 vectors unchanged under a hostile cwd and environment"

runHook postInstallCheck
