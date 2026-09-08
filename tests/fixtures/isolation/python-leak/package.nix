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
  installPhase = ''
    mkdir -p $out/bin $out/lib
    printf '%s\n' 'import sys' 'print("ok", len(sys.argv) - 1)' > $out/lib/main.py
    makeWrapper ${python3}/bin/python3 $out/bin/python-leak --add-flags "$out/lib/main.py"
  '';
  passthru = {
    kind = "cli";
    bins = ["python-leak"];
    smoke.python-leak = [["--version"]];
    runtime = "python";
  };
}
