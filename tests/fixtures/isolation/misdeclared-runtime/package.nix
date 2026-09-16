# Red fixture: a babashka script declared as a native binary, which would
# skip the hostile injection if the guard trusted the declaration.
{
  stdenvNoCC,
  babashka,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "misdeclared-runtime";
  version = "0";
  dontUnpack = true;
  nativeBuildInputs = [makeWrapper];
  bbExe = "${babashka}/bin/bb";
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    bins = ["misdeclared-runtime"];
    smoke.misdeclared-runtime = [[]];
    runtime = "none";
  };
}
