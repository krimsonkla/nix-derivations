#!/usr/bin/env bash
# knotview install. Sourced by installPhase, never executed: makeWrapper and
# runHook are functions the build environment defines in the shell, and a
# separate process would not have them.
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

runHook preInstall

mkdir -p "$out/lib/knotview" "$out/bin"
# The package tree as upstream lays it out under src/, plus the launcher
# beside it. Templates and stylesheets travel with it: pyproject.toml declares
# them as package data, and a copy of the python alone would build a panel
# that cannot mount its pages.
cp -r src/knotview "$out/lib/knotview/"
cp "$launcher" "$out/lib/knotview/main.py"

# PATH is deliberately not set: knotview runs `knot`, which the consumer's
# tickets layer supplies, and a private PATH here would hide it. Every
# variable this python honours is unset by the scrub, so what the consumer's
# shell exports cannot reach the interpreter.
# shellcheck source=/dev/null # a store path, resolved at build time
source "$isolationWrapper"
wrap_isolated \
  --exe "$pythonExe" \
  --name knotview \
  --flags "$out/lib/knotview/main.py"

runHook postInstall
