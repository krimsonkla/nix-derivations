# Red fixture: a package with no passthru.kind at all.
{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "unkinded";
  version = "0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    printf '#!/bin/sh\necho ok\n' > $out/bin/unkinded && chmod +x $out/bin/unkinded
  '';
}
