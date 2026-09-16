{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  babashka,
  clj-kondo,
  ripgrep,
  gnugrep,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "clj-surgeon";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "realgenekim";
    repo = "clj-surgeon";
    rev = "8325ff425410569ddc7ecd2fd01afaf8f6a8b140";
    hash = "sha256-fQxU7fJMJ7axPRU8NCXuMbRiL14j462zjHEn32S3iQ0=";
  };
  patches = [];
  nativeBuildInputs = [makeWrapper babashka];
  # Host-offset: the admission script is patched to this python and execs
  # under it in the consumer's shell, so it is a runtime reference.
  buildInputs = [python3];
  dontBuild = true;

  # What the phase scripts need from Nix. Everything else they derive from
  # $out themselves, which is the point of moving them out of here.
  bbExe = "${babashka}/bin/bb";
  requireMain = ./require-main.clj;

  # The family table stays the single source of the scrub list: Nix exports
  # the babashka row, the shared shell helper spends it. No shell here.
  isolationScrub = (import ../../../../lib/isolation.nix {inherit lib;}).families.babashka.scrub;
  isolationWrapper = ../../../../lib/scripts/wrap-isolated.sh;
  isolationBinPath = lib.makeBinPath [clj-kondo ripgrep gnugrep];

  # Sourced, not executed: makeWrapper, patchShebangs and runHook are shell
  # functions of the build environment, and a child process would not have
  # them.
  installPhase = "source ${./scripts/install.sh}";
  doInstallCheck = true;
  installCheckPhase = "source ${./scripts/install-check.sh}";

  passthru = {
    kind = "cli";
    bins = ["clj-surgeon"];
    smoke.clj-surgeon = [["--version"]];
    runtime = "babashka";
  };

  meta = {
    description = "Structural operations on Clojure namespaces for agent workflows";
    homepage = "https://github.com/realgenekim/clj-surgeon";
    license = lib.licenses.mit;
    mainProgram = "clj-surgeon";
    platforms = ["x86_64-linux" "aarch64-darwin"];
  };
}
