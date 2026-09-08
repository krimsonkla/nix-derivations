#!/usr/bin/env bash
# The hostile environment per runtime family: what the isolation guard sets
# when it runs a cli's smoke vectors the second time, from a copy of
# tests/fixtures/isolation-hostile/<family>/. Sourced by the guard, never
# executed. lib/isolation.nix is the Nix half (set, scrub and interpreter
# match per family); the guard asserts the two name the same families, so a
# family added to one and not the other is a named failure.
# HIJACKED is the marker the guard greps for in the hostile run's output.

hostile_families() { printf '%s\n' babashka dotnet jvm node none perl python ruby shell; }

# hostile_env <family> <fixture-dir> -> NAME=value lines
hostile_env() {
  local dir="$2"
  case "$1" in
    babashka)
      printf '%s\n' "BABASHKA_PRELOADS=(println \"HIJACKED-BY-ENV\")" "BABASHKA_CLASSPATH=$dir/hijack"
      ;;
    python)
      # NIX_PYTHONPATH is the entry nixpkgs' sitecustomize hands to
      # site.addsitedir, which executes hijack.pth in the fixture directory.
      printf '%s\n' "PYTHONPATH=$dir" "NIX_PYTHONPATH=$dir" "PYTHONSTARTUP=$dir/sitecustomize.py" "PYTHONUSERBASE=$dir"
      ;;
    node)
      printf '%s\n' "NODE_PATH=$dir" "NODE_OPTIONS=--require=$dir/hijack.js"
      ;;
    jvm)
      printf '%s\n' "CLASSPATH=$dir" "JAVA_TOOL_OPTIONS=-XX:+PrintFlagsFinal" "_JAVA_OPTIONS=-XX:+PrintFlagsFinal" "JDK_JAVA_OPTIONS=-XX:+PrintFlagsFinal"
      ;;
    shell)
      printf '%s\n' "BASH_ENV=$dir/hijack.sh" "ENV=$dir/hijack.sh"
      ;;
    ruby)
      printf '%s\n' "RUBYLIB=$dir" "RUBYOPT=-rhijack" "GEM_PATH=$dir" "GEM_HOME=$dir"
      ;;
    perl)
      printf '%s\n' "PERL5LIB=$dir" "PERL5OPT=-MHijack" "PERLLIB=$dir"
      ;;
    dotnet)
      printf '%s\n' "DOTNET_STARTUP_HOOKS=$dir/hijack.dll" "DOTNET_ROOT=$dir"
      ;;
    none) ;;
    *)
      echo "isolation-hostile: unknown family $1" >&2
      return 1
      ;;
  esac
}
