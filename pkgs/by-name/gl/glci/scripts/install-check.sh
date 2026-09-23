#!/usr/bin/env bash
# glci install check. Three moves: the binary reports the commit this
# derivation pinned, the two declared commands answer under an empty
# environment, and their answers are byte-identical from a directory holding a
# hostile glci configuration.
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

# The stamp against the pin. glci resolves the container image it runs jobs in
# by this commit, so a binary reporting anything else would send a consumer to
# an image built from source this package did not fetch. Both values are the
# derivation's own, which is what makes the ldflags path being wrong -- the
# linker ignores a -X whose path is not the module path, silently -- fail here.
clean=(env -i "HOME=$HOME" "PATH=$out/bin")
empty=$(mktemp -d)
# Both streams: glci prints its version banner on stderr, so a stdout-only
# capture would compare two empty strings and pass while proving nothing.
reported=$(cd "$empty" && "${clean[@]}" glci version 2>&1)
grep -qF "$pinnedRev" <<<"$reported" || {
  echo "glci version printed '$reported', which does not carry the pinned rev $pinnedRev"
  exit 1
}
echo "stamp: glci reports the pinned commit $pinnedRev"

# The commands a consumer's shell is promised, under an empty environment: a
# binary that only works while the build's own variables are set must fail
# here, not in a consumer.
help=$(cd "$empty" && "${clean[@]}" glci --help 2>&1)
grep -q 'Run GitLab CI/CD pipelines locally' <<<"$help" || {
  echo "glci --help printed: $help"
  exit 1
}

# Isolation: the same two commands from a directory holding a configuration
# glci would honour if it read the working directory for these commands, and an
# image override pointing somewhere else entirely. Neither command takes a
# pipeline, so both must answer the same bytes as above. The file is written
# here rather than taken from tests/, so the package's hash depends on nothing
# outside pkgs/.
h=$(mktemp -d)
printf '%s\n' '[images]' 'glci = "example.invalid/HIJACKED:latest"' > "$h/.glciconfig.toml"
hv=$(cd "$h" && "${clean[@]}" glci version 2>&1)
hh=$(cd "$h" && "${clean[@]}" glci --help 2>&1)
[ "$hv" = "$reported" ] && [ "$hh" = "$help" ] \
  || { echo "output changed under a hostile working directory"; exit 1; }
if grep -q HIJACKED <<<"$hv$hh"; then echo "hijack marker in output"; exit 1; fi
echo "isolation: 2 vectors unchanged under a hostile working directory"

runHook postInstallCheck
