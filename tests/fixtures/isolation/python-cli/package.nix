# Green fixture: a python cli wrapped with the shared helper, the witness that
# the python family's scrub list defeats the family's hostile injection.
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "python-cli";
  version = "0";
  dontUnpack = true;
  nativeBuildInputs = [makeWrapper];
  pythonExe = "${python3}/bin/python3";
  isolationScrub = (import ../../../../lib/isolation.nix {inherit lib;}).families.python.scrub;
  isolationWrapper = ../../../../lib/scripts/wrap-isolated.sh;
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    bins = ["python-cli"];
    smoke.python-cli = [["--version"]];
    runtime = "python";
  };
}
