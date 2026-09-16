# Red fixture: the same python cli wrapped with a bare makeWrapper, which
# leaves NIX_PYTHONPATH and PYTHONPATH in force, so the hostile run imports
# the injected module and prints its marker.
{
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "python-leak";
  version = "0";
  dontUnpack = true;
  nativeBuildInputs = [makeWrapper];
  pythonExe = "${python3}/bin/python3";
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    bins = ["python-leak"];
    smoke.python-leak = [["--version"]];
    runtime = "python";
  };
}
