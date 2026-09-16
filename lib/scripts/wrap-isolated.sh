#!/usr/bin/env bash
# Shell half of the cli wrapper lib/isolation.nix describes. The Nix half
# exports one family's scrub list as $isolationScrub; this turns it, any
# variables the tool itself reads and a closed PATH into a single makeWrapper
# call, so that no package expression carries shell of its own.
#
# PATH is SET, never prefixed. A cli here owns a private runtime, and a prefix
# would leave the consumer's PATH reachable behind ours, which is the
# composition hazard the kind exists to prevent: the tool would find the
# consumer's executable whenever ours lacks the name. Setting it means an
# executable the package did not declare is simply absent, which fails visibly
# instead of resolving to something else.
#
# makeWrapper emits the sets as `export NAME=` lines ahead of the `exec` line
# the isolation guard's detect_family anchors on, so neither the variables nor
# PATH disturb family detection. makeBinaryWrapper would: its fallback branch
# takes the first store path found anywhere in the binary, which a PATH entry
# can win over the interpreter, so a cli using this stays on makeWrapper.

# wrap_isolated --exe PATH --name NAME [--set NAME=VALUE]... [--path DIRS]
#               [--flags STRING]
# The derivation's own attributes -- $out and everything package.nix
# exports -- arrive from the build environment, so shellcheck cannot see
# where they were assigned.
# shellcheck disable=SC2154

wrap_isolated() {
  local exe="" name="" flags="" binpath=""
  local -a sets=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --exe) exe=$2; shift 2 ;;
      --name) name=$2; shift 2 ;;
      --flags) flags=$2; shift 2 ;;
      --path) binpath=$2; shift 2 ;;
      --set) sets+=("$2"); shift 2 ;;
      *)
        echo "wrap_isolated: unknown argument '$1'" >&2
        return 2
        ;;
    esac
  done

  [ -n "$exe" ] || { echo "wrap_isolated: --exe is required" >&2; return 2; }
  [ -n "$name" ] || { echo "wrap_isolated: --name is required" >&2; return 2; }
  # Unset rather than empty: an empty scrub list is a real answer for the none
  # family, but a missing variable means the family table never reached this
  # build, and wrapping without the scrub is the failure the guard exists to
  # catch. Fail here instead of shipping an unscrubbed wrapper.
  [ -n "${isolationScrub+x}" ] \
    || { echo "wrap_isolated: isolationScrub is unset; lib/isolation.nix's family table did not reach this build" >&2; return 2; }

  local -a args=()
  local v
  for v in $isolationScrub; do args+=(--unset "$v"); done
  for v in "${sets[@]}"; do args+=(--set "${v%%=*}" "${v#*=}"); done
  [ -n "$binpath" ] && args+=(--set PATH "$binpath")

  makeWrapper "$exe" "$out/bin/$name" "${args[@]}" --add-flags "$flags"
}
