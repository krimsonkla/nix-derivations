{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  babashka,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "knot";
  version = "0.15.0";
  src = fetchFromGitHub {
    owner = "UniSoma";
    repo = "knot";
    rev = "9956d45f8297c0eb3a0f1650fcbb5397ea70e408";
    hash = "sha256-BYY5vQd48wMOHSEep3dVJCH/mI8+XNd3IPfrARDtiKA=";
  };
  patches = [];
  nativeBuildInputs = [makeWrapper babashka];
  dontBuild = true;

  # What the phase scripts need from Nix. Everything else they derive from
  # $out themselves, which is the point of moving them out of here.
  bbExe = "${babashka}/bin/bb";
  requireAll = ./require-all.clj;

  # The family table stays the single source of the scrub list: Nix exports
  # the babashka row, the shared shell helper spends it. No shell here.
  isolationScrub = (import ../../../../lib/isolation.nix {inherit lib;}).families.babashka.scrub;
  isolationWrapper = ../../../../lib/scripts/wrap-isolated.sh;

  # Sourced, not executed: makeWrapper and runHook are shell functions of the
  # build environment, and a child process would not have them.
  installPhase = "source ${./scripts/install.sh}";
  doInstallCheck = true;
  installCheckPhase = "source ${./scripts/install-check.sh}";

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
}
