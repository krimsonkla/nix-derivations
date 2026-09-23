{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  makeWrapper,
}: let
  # The four runtime dependencies pyproject.toml declares, and nothing else:
  # knotview reads its backlog by running knot, which is the tickets layer's
  # command on the consumer's PATH rather than a dependency of this closure.
  runtime = python3.withPackages (ps: [
    ps.fastapi
    ps.jinja2
    ps.markdown-it-py
    ps.uvicorn
  ]);
in
  stdenvNoCC.mkDerivation {
    pname = "knotview";
    version = "0.1.0";
    src = fetchFromGitHub {
      owner = "krimsonkla";
      repo = "knotview";
      rev = "b765e2cb449d36063a0403a483e0004611f53b9b";
      hash = "sha256-EbUf67eJTWyCjpTw1s8hJLXIeKE0u5IGOz9G49g7EuU=";
    };
    patches = [];
    nativeBuildInputs = [makeWrapper];
    dontBuild = true;

    # What the phase scripts need from Nix. Everything else they derive from
    # $out themselves, which is the point of moving them out of here.
    pythonExe = "${runtime}/bin/python3";
    launcher = ./main.py;
    importAll = ./import-all.py;

    # The family table stays the single source of the scrub list: Nix exports
    # the python row, the shared shell helper spends it. No shell here.
    isolationScrub = (import ../../../../lib/isolation.nix {inherit lib;}).families.python.scrub;
    isolationWrapper = ../../../../lib/scripts/wrap-isolated.sh;

    # Sourced, not executed: makeWrapper and runHook are shell functions of the
    # build environment, and a child process would not have them.
    installPhase = "source ${./scripts/install.sh}";
    doInstallCheck = true;
    installCheckPhase = "source ${./scripts/install-check.sh}";

    passthru = {
      kind = "cli";
      bins = ["knotview"];
      # Both vectors answer from the command alone: the help text, and the
      # refusal a name nothing was saved under earns. Neither reads the
      # working directory, which the hostile run moves.
      smoke.knotview = [["--help"] ["nosuchproject"]];
      runtime = "python";
    };

    meta = {
      description = "Read-only web panel over a knot backlog";
      homepage = "https://github.com/krimsonkla/knotview";
      license = lib.licenses.mit;
      mainProgram = "knotview";
      platforms = ["x86_64-linux" "aarch64-darwin"];
    };
  }
