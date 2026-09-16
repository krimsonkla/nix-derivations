#!/usr/bin/env bash
# clj-surgeon install check. Four moves, following knot's: the entry namespace
# and its closure load, the runtime floor holds, the declared command works
# under an empty environment, and its output is byte-identical from a hostile
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
cfg=$out/lib/clj-surgeon/bb.edn
cp=$out/lib/clj-surgeon/src:$out/lib/clj-surgeon/resources

# The entry namespace and its whole closure load under this babashka. This
# phase is where the source-only claim is established rather than assumed: the
# sandbox has no network and no populated ~/.m2, so a rev that grows a
# load-time babashka.deps/add-deps call fails here by name. A developer-machine
# run proves neither, because babashka is a native image that reads user.home
# from the passwd entry and finds a warm ~/.m2 whatever $HOME says.
"$bbExe" --config "$cfg" --deps-root "$out/lib/clj-surgeon" --classpath "$cp" \
  "$requireMain" clj-surgeon.core

# The floor bb.edn states, read from the source so an upstream bump is picked
# up. Upstream declares none today; the move stays so the first rev that
# declares one is enforced rather than ignored.
floor=$("$bbExe" -e "(println (or (-> \"$cfg\" slurp clojure.edn/read-string :min-bb-version) \"\"))")
have=$("$bbExe" --version | sed -E 's/^babashka v//')
if [ -n "$floor" ]; then
  "$bbExe" -e "(let [v (fn [s] (mapv parse-long (clojure.string/split s #\"\\.\")))]
                 (when (neg? (compare (v \"$have\") (v \"$floor\"))) (System/exit 1)))" \
    || { echo "babashka $have is below the floor $floor"; exit 1; }
  echo "babashka floor: $have >= $floor"
else
  echo "babashka floor: $have, upstream bb.edn declares no :min-bb-version"
fi

# The command a consumer's shell is promised, under an empty environment: a
# wrapper that only works while the build's own variables (out, src) are set
# must fail here, not in a consumer.
clean=(env -i "HOME=$HOME" "PATH=$out/bin")
# $version is the derivation's own attribute, so the tool's self-report and
# the packaged version cannot drift apart silently.
if ! reported=$("${clean[@]}" clj-surgeon --version 2>&1); then
  echo "clj-surgeon --version failed: $reported"
  exit 1
fi
grep -qF "\"$version\"" <<<"$reported" \
  || { echo "clj-surgeon --version printed '$reported'"; exit 1; }

# Both sides of the admission split, against a file this output ships. :cat
# needs no executable and no variable at all; :ls refuses with
# :clj-kondo-admission-unavailable unless the admission script and clj-kondo
# both reached the tool through the wrapper, which is the whole reason the
# wrapper sets a variable and a PATH.
subject=$out/lib/clj-surgeon/src/clj_surgeon/forms.clj
if ! cat_out=$("${clean[@]}" clj-surgeon :op :cat :file "$subject" :contains 'ns clj-surgeon.forms' 2>&1); then
  echo "clj-surgeon :cat failed: $cat_out"
  exit 1
fi
grep -q ':operation :show-form' <<<"$cat_out" \
  || { echo "clj-surgeon :cat printed: $cat_out"; exit 1; }

# The gate serialises analyzer runs through a lock and an event log, and
# resolves both under the JVM's user.home rather than $HOME. babashka is a
# native image that takes user.home from the passwd entry, which in this
# sandbox is the unwritable /homeless-shelter, so the lock could never be taken
# and the gate would report :delegated forever. These name writable paths for
# the check only; they are a consumer's own per-user state and the wrapper
# deliberately does not set them.
state=$(mktemp -d)
gate_state=(
  "CLJ_SURGEON_CLJ_KONDO_LOCK=$state/clj-kondo.lock"
  "CLJ_SURGEON_CLJ_KONDO_PRIORITY_LOCK=$state/clj-kondo-priority.lock"
  "CLJ_SURGEON_CLJ_KONDO_EVENTS=$state/clj-kondo-events.jsonl"
)
if ! ls_out=$("${clean[@]}" "${gate_state[@]}" clj-surgeon :op :ls :file "$subject" 2>&1); then
  echo "clj-surgeon :ls failed: $ls_out"
  exit 1
fi
if grep -q 'admission-unavailable' <<<"$ls_out"; then
  echo "clj-surgeon :ls refused the admission gate: $ls_out"
  exit 1
fi
grep -q ':ns clj-surgeon.forms' <<<"$ls_out" \
  || { echo "clj-surgeon :ls printed: $ls_out"; exit 1; }
echo "admission: :cat runs bare, :ls reaches clj-kondo through the wrapper"

# Isolation: the same commands from a directory holding a hostile bb.edn and
# under the variables babashka honours, byte-identical, no marker. The hostile
# files are written here rather than taken from tests/, so the package's hash
# depends on nothing outside pkgs/ and lib/; the :deps value is not valid EDN
# so a read fails at the parse, never a resolution. :ls is deliberately not
# compared: it takes a lock and writes an event log, so it is the admission
# assertion above rather than a byte-for-byte pair.
h=$(mktemp -d) && mkdir -p "$h/hijack/clj_surgeon"
printf '%s\n' '{:paths ["hijack"]' ' :deps {this-is-not-edn}}' > "$h/bb.edn"
printf '%s\n' '(ns clj-surgeon.core)' '(defn -main [& _] (println "HIJACKED-BY-CWD"))' \
  > "$h/hijack/clj_surgeon/core.clj"
hostile=(
  'BABASHKA_PRELOADS=(println "HIJACKED-BY-ENV")'
  "BABASHKA_CLASSPATH=$h/hijack"
)
hv=$(cd "$h" && "${clean[@]}" "${hostile[@]}" clj-surgeon --version 2>&1)
hc=$(cd "$h" && "${clean[@]}" "${hostile[@]}" clj-surgeon :op :cat :file "$subject" :contains 'ns clj-surgeon.forms' 2>&1)
[ "$hv" = "$reported" ] && [ "$hc" = "$cat_out" ] \
  || { echo "output changed under a hostile cwd or environment"; exit 1; }
if grep -q HIJACKED <<<"$hv$hc"; then echo "hijack marker in output"; exit 1; fi
echo "isolation: 2 invocations unchanged under a hostile cwd and environment"

runHook postInstallCheck
