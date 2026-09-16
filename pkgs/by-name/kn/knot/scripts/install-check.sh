#!/usr/bin/env bash
# knot install check. Four moves: every namespace loads, the runtime floor
# holds, the two declared commands work under an empty environment, and their
# output is byte-identical from a hostile directory and environment.
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
cfg=$out/lib/knot/bb.edn
cp=$out/lib/knot/src:$out/lib/knot/resources

# Every namespace loads under this babashka: an unbundled library fails here
# with its name, not later in a subcommand.
"$bbExe" --config "$cfg" --deps-root "$out/lib/knot" --classpath "$cp" \
  "$requireAll" "$out/lib/knot/src"

# The floor bb.edn states, read from the source so an upstream bump is picked
# up, against the babashka that will run knot.
floor=$("$bbExe" -e "(-> \"$cfg\" slurp clojure.edn/read-string :min-bb-version println)")
have=$("$bbExe" --version | sed -E 's/^babashka v//')
"$bbExe" -e "(let [v (fn [s] (mapv parse-long (clojure.string/split s #\"\\.\")))]
               (when (neg? (compare (v \"$have\") (v \"$floor\"))) (System/exit 1)))" \
  || { echo "babashka $have is below the floor $floor"; exit 1; }
echo "babashka floor: $have >= $floor"

# The two commands a consumer's shell is promised, under an empty environment:
# a wrapper that only works while the build's own variables (out, src) are set
# must fail here, not in a consumer. $version is the derivation's own
# attribute, so the tool's self-report and the packaged version cannot drift
# apart silently.
clean=(env -i "HOME=$HOME" "PATH=$out/bin")
reported=$("${clean[@]}" knot --version)
[ "$reported" = "$version" ] || { echo "knot --version printed '$reported'"; exit 1; }
empty=$(mktemp -d)
prime=$(cd "$empty" && "${clean[@]}" knot prime --json)
if ! grep -q '"ok":true' <<<"$prime" || ! grep -q '"found":false' <<<"$prime"; then
  echo "knot prime --json in an empty directory printed: $prime"
  exit 1
fi

# Isolation: the same commands from a directory holding a hostile bb.edn and
# under the variables babashka honours, byte-identical, no marker. The hostile
# files are written here rather than taken from tests/, so the package's hash
# depends on nothing outside pkgs/ and lib/; the :deps value is not valid EDN
# so a read fails at the parse, never a resolution.
h=$(mktemp -d) && mkdir -p "$h/hijack/knot"
printf '%s\n' '{:paths ["hijack"]' ' :deps {this-is-not-edn}}' > "$h/bb.edn"
printf '%s\n' '(ns knot.main)' '(defn -main [& _] (println "HIJACKED-BY-CWD"))' \
  > "$h/hijack/knot/main.clj"
hostile=(
  'BABASHKA_PRELOADS=(println "HIJACKED-BY-ENV")'
  "BABASHKA_CLASSPATH=$h/hijack"
)
hv=$(cd "$h" && "${clean[@]}" "${hostile[@]}" knot --version)
hp=$(cd "$h" && "${clean[@]}" "${hostile[@]}" knot prime --json)
[ "$hv" = "$reported" ] && [ "$hp" = "$prime" ] \
  || { echo "output changed under a hostile cwd or environment"; exit 1; }
if grep -q HIJACKED <<<"$hv$hp"; then echo "hijack marker in output"; exit 1; fi
echo "isolation: 2 commands unchanged under a hostile cwd and environment"

runHook postInstallCheck
