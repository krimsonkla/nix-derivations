# Package kinds and runtime families. One table for every family, read by the
# flake (the overlay's library placement and the fixpoint check) and exported
# to the isolation guard as JSON; tests/isolation-hostile.bash is the bash
# half (hostile environment per family) and the guard holds the two equal.
{lib}: rec {
  kinds = ["cli" "library"];

  # set: the language set a library of this family extends, null when the
  # family has no library idiom yet (declaring a library there is a named
  # failure, not a guess). interpreter: the attribute whose override carries
  # the set through the fixpoint (`python3.override { packageOverrides }`),
  # the idiom devenv-layers' common layer uses for python312. scrub: the
  # variables a cli wrapper of this family unsets, the same list the guard
  # injects.
  families = {
    babashka = {
      set = null;
      interpreter = null;
      scrub = ["BABASHKA_PRELOADS" "BABASHKA_CLASSPATH"];
    };
    python = {
      set = "python3Packages";
      interpreter = "python3";
      scrub = ["PYTHONPATH" "PYTHONHOME" "PYTHONSTARTUP"];
    };
    node = {
      set = null;
      interpreter = null;
      scrub = ["NODE_PATH" "NODE_OPTIONS"];
    };
    jvm = {
      set = null;
      interpreter = null;
      scrub = ["CLASSPATH" "JAVA_TOOL_OPTIONS"];
    };
    none = {
      set = null;
      interpreter = null;
      scrub = [];
    };
  };

  # The makeWrapper invocation for a cli of one family: every variable the
  # family honours is unset before the interpreter starts. `flags` is the
  # --add-flags string, double-quoted so `$out` expands at install time (a
  # single-quoted string bakes the literal, which only works while the
  # build environment still defines it); `exe` the interpreter path; `name`
  # the command.
  wrapIsolated = {
    family,
    exe,
    name,
    flags,
  }: let
    unsets = lib.concatMapStringsSep " " (v: "--unset ${v}") families.${family}.scrub;
  in "makeWrapper ${exe} $out/bin/${name} ${unsets} --add-flags \"${flags}\"";

  # Family of a library from its declared set, or null.
  familyOfSet = set: let
    hits = lib.filterAttrs (_: f: f.set == set) families;
  in
    if hits == {}
    then null
    else lib.head (lib.attrNames hits);
}
