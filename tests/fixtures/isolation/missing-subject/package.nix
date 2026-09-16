# Red fixture: a cli that declares its kind and forgets its subject.
{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "missing-subject";
  version = "0";
  dontUnpack = true;
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    runtime = "shell";
  };
}
