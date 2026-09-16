# Red fixture: a cli whose interpreter matches no family row.
{
  stdenvNoCC,
  lua,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "unknown-family";
  version = "0";
  dontUnpack = true;
  nativeBuildInputs = [makeWrapper];
  luaExe = "${lua}/bin/lua";
  installPhase = "source ${./scripts/install.sh}";
  passthru = {
    kind = "cli";
    bins = ["unknown-family"];
    smoke.unknown-family = [[]];
    runtime = "none";
  };
}
