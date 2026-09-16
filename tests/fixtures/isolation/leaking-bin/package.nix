# Red fixture: a cli whose bin/ also carries its interpreter.
{
  stdenvNoCC,
  babashka,
}:
stdenvNoCC.mkDerivation {
  pname = "leaking-bin";
  version = "0";
  dontUnpack = true;
  bbExe = "${babashka}/bin/bb";
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    bins = ["leaking-bin"];
    smoke.leaking-bin = [[]];
    runtime = "shell";
  };
}
