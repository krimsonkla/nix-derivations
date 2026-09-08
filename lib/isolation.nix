# Package kinds and runtime families. One table for every family, read by the
# flake (the overlay's library placement and the fixpoint check) and exported
# to the isolation guard as JSON; tests/isolation-hostile.bash is the bash
# half (the hostile environment per family) and the guard holds the two
# equal. The families are the runtimes packages here are expected to run
# under, plus the popular ones with an injection variable; a runtime outside
# this table is a named failure, never a guess.
{lib}: rec {
  # cli: a command with a private runtime. library: extends a language set.
  # asset: data consumed by path (a model cache, a schema), never on PATH.
  kinds = ["cli" "library" "asset"];

  # set: the language set a library of this family extends, null when the
  # family has no library idiom yet (declaring a library there is a named
  # failure, not a guess). interpreter: the attribute whose override carries
  # the set through the fixpoint (`python3.override { packageOverrides }`,
  # nixpkgs' own idiom for extending a python package set). scrub: the
  # variables a cli wrapper of this family unsets, the same list the guard
  # injects. match: store-path name prefixes the guard recognises as this
  # family's interpreter when it inspects a cli's bin/; `none` matches nothing
  # because it means a native executable, never a script.
  families = {
    babashka = {
      set = null;
      interpreter = null;
      scrub = ["BABASHKA_PRELOADS" "BABASHKA_CLASSPATH"];
      match = ["babashka"];
    };
    python = {
      set = "python3Packages";
      interpreter = "python3";
      scrub = ["PYTHONPATH" "PYTHONHOME" "PYTHONSTARTUP" "PYTHONUSERBASE"];
      match = ["python3" "python-"];
    };
    node = {
      set = null;
      interpreter = null;
      scrub = ["NODE_PATH" "NODE_OPTIONS"];
      match = ["nodejs"];
    };
    jvm = {
      set = null;
      interpreter = null;
      scrub = ["CLASSPATH" "JAVA_TOOL_OPTIONS" "_JAVA_OPTIONS" "JDK_JAVA_OPTIONS"];
      match = ["openjdk" "zulu" "temurin" "jdk" "jre" "graalvm"];
    };
    shell = {
      set = null;
      interpreter = null;
      scrub = ["BASH_ENV" "ENV"];
      match = ["bash" "dash" "zsh"];
    };
    ruby = {
      set = null;
      interpreter = null;
      scrub = ["RUBYLIB" "RUBYOPT" "GEM_PATH" "GEM_HOME"];
      match = ["ruby"];
    };
    perl = {
      set = null;
      interpreter = null;
      scrub = ["PERL5LIB" "PERL5OPT" "PERLLIB"];
      match = ["perl"];
    };
    dotnet = {
      set = null;
      interpreter = null;
      scrub = ["DOTNET_STARTUP_HOOKS" "DOTNET_ROOT"];
      match = ["dotnet"];
    };
    none = {
      set = null;
      interpreter = null;
      scrub = [];
      match = [];
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

  # One row per index entry, everything the guard needs, evaluated from the
  # same expressions that produce the outputs. `overlaid` is nixpkgs with the
  # overlay applied; the library booleans come from it.
  manifest = {
    index,
    packages,
    overlaid,
  }:
    lib.mapAttrsToList (name: e: let
      p = packages.${name};
      pt = p.passthru or {};
      set = pt.set or null;
      fam =
        if set == null
        then null
        else familyOfSet set;
      interp =
        if fam == null
        then null
        else families.${fam}.interpreter;
      # A dynamic attribute name must be a string: `attrs.${null} or x` throws
      # rather than defaulting, so a cli (set = null) is guarded explicitly.
      # A removed set is a throwing alias in nixpkgs (`nodePackages has been
      # removed`), which `or` does not catch either, so the lookup is tried.
      viaSet =
        if set == null
        then null
        else let
          r = builtins.tryEval (overlaid.${set}.${name} or null);
        in
          if r.success
          then r.value
          else null;
      viaInterp =
        if interp == null
        then null
        else overlaid.${interp}.pkgs.${name} or null;
    in {
      inherit name set;
      index_kind = e.kind or null;
      index_set = e.set or null;
      kind = pt.kind or null;
      bins = pt.bins or null;
      smoke = pt.smoke or null;
      runtime = pt.runtime or null;
      files = pt.files or null;
      out = "${p}";
      propagated_build_inputs = map toString (p.propagatedBuildInputs or []);
      propagated_native_build_inputs = map toString (p.propagatedNativeBuildInputs or []);
      propagated_user_env_pkgs = map toString (p.propagatedUserEnvPkgs or []);
      top_level_absent = !(overlaid ? ${name});
      set_present = viaSet != null;
      fixpoint_equal = viaSet != null && viaInterp != null && "${viaSet}" == "${viaInterp}";
    })
    index;
}
