# Green fixture: a python cli wrapped with the shared helper, the witness that
# the python family's scrub list defeats the family's hostile injection.
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}: let
  isolation = import ../../../../lib/isolation.nix {inherit lib;};
in
  stdenvNoCC.mkDerivation {
    pname = "python-cli";
    version = "0";
    dontUnpack = true;
    nativeBuildInputs = [makeWrapper];
    installPhase = ''
      mkdir -p $out/bin $out/lib
      printf '%s\n' 'import sys' 'print("ok", len(sys.argv) - 1)' > $out/lib/main.py
      ${isolation.wrapIsolated {
        family = "python";
        exe = "${python3}/bin/python3";
        name = "python-cli";
        flags = "$out/lib/main.py";
      }}
    '';
    passthru = {
      kind = "cli";
      bins = ["python-cli"];
      smoke.python-cli = [["--version"]];
      runtime = "python";
    };
  }
