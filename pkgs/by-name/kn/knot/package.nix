{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  babashka,
  makeWrapper,
}: let
  isolation = import ../../../../lib/isolation.nix {inherit lib;};
  hostile = ../../../../tests/fixtures/isolation-hostile/babashka;
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "knot";
    version = "0.12.0";
    src = fetchFromGitHub {
      owner = "UniSoma";
      repo = "knot";
      rev = "5c2a42062e94809b1a51df372cab78f9f750fe52";
      hash = "sha256-/cCMX281CeW67ioESvtTdTc7oSoGgc7BkLPZAqkKhBo=";
    };
    patches = [];
    nativeBuildInputs = [makeWrapper babashka];
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/knot $out/bin
      cp -r src resources bb.edn $out/lib/knot/
      ${isolation.wrapIsolated {
        family = "babashka";
        exe = "${babashka}/bin/bb";
        name = "knot";
        flags = "--config $out/lib/knot/bb.edn --deps-root $out/lib/knot --classpath $out/lib/knot/src:$out/lib/knot/resources -m knot.main";
      }}
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      export HOME=$(mktemp -d)
      bb=${babashka}/bin/bb
      cp=$out/lib/knot/src:$out/lib/knot/resources

      # Every namespace loads under this babashka: an unbundled library fails
      # here with its name, not later in a subcommand.
      $bb --config $out/lib/knot/bb.edn --deps-root $out/lib/knot --classpath $cp \
        ${./require-all.clj} $out/lib/knot/src

      # The floor bb.edn states, read from the source so an upstream bump is
      # picked up, against the babashka that will run knot.
      floor=$($bb -e "(-> \"$out/lib/knot/bb.edn\" slurp clojure.edn/read-string :min-bb-version println)")
      have=$($bb --version | sed -E 's/^babashka v//')
      $bb -e "(let [v (fn [s] (mapv parse-long (clojure.string/split s #\"\\.\")))]
                (when (neg? (compare (v \"$have\") (v \"$floor\"))) (System/exit 1)))" \
        || { echo "babashka $have is below the floor $floor"; exit 1; }
      echo "babashka floor: $have >= $floor"

      # The two commands a consumer's shell is promised, under an empty
      # environment: a wrapper that only works while the build's own
      # variables (out, src) are set must fail here, not in a consumer.
      clean="env -i HOME=$HOME PATH=$out/bin"
      version=$($clean knot --version)
      [ "$version" = "${finalAttrs.version}" ] || { echo "knot --version printed '$version'"; exit 1; }
      empty=$(mktemp -d)
      prime=$(cd $empty && $clean knot prime --json)
      grep -q '"ok":true' <<<"$prime" && grep -q '"found":false' <<<"$prime" \
        || { echo "knot prime --json in an empty directory printed: $prime"; exit 1; }

      # Isolation: the same commands from a directory holding a hostile bb.edn
      # and under the variables babashka honours, byte-identical, no marker.
      h=$(mktemp -d) && cp -r ${hostile}/. $h
      hv=$(cd $h && $clean BABASHKA_PRELOADS='(println "HIJACKED-BY-ENV")' BABASHKA_CLASSPATH=$h/hijack knot --version)
      hp=$(cd $h && $clean BABASHKA_PRELOADS='(println "HIJACKED-BY-ENV")' BABASHKA_CLASSPATH=$h/hijack knot prime --json)
      [ "$hv" = "$version" ] && [ "$hp" = "$prime" ] || { echo "output changed under a hostile cwd or environment"; exit 1; }
      ! grep -q HIJACKED <<<"$hv$hp"
      echo "isolation: 2 commands unchanged under a hostile cwd and environment"
      runHook postInstallCheck
    '';

    passthru = {
      kind = "cli";
      bins = ["knot"];
      smoke.knot = [["--version"] ["prime" "--json"]];
      runtime = "babashka";
    };

    meta = {
      description = "File-based, git-native ticket tracker for agent-first workflows";
      homepage = "https://github.com/UniSoma/knot";
      license = lib.licenses.mit;
      mainProgram = "knot";
      platforms = ["x86_64-linux" "aarch64-darwin"];
    };
  })
