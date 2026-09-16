# Red fixture: a package with no passthru.kind at all.
{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "unkinded";
  version = "0";
  dontUnpack = true;
  installPhase = "source ${./scripts/install.sh}";
}
