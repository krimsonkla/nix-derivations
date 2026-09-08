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
  installPhase = ''
    mkdir -p $out/bin
    makeWrapper ${lua}/bin/lua $out/bin/unknown-family --add-flags "-e 'print(1)'"
  '';
  passthru = {
    kind = "cli";
    bins = ["unknown-family"];
    smoke.unknown-family = [[]];
    runtime = "none";
  };
}
