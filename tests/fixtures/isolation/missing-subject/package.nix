# Red fixture: a cli that declares its kind and forgets its subject.
{stdenvNoCC}:
stdenvNoCC.mkDerivation {
  pname = "missing-subject";
  version = "0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    printf '#!/bin/sh\necho ok\n' > $out/bin/missing-subject && chmod +x $out/bin/missing-subject
  '';
  passthru = {
    kind = "cli";
    runtime = "shell";
  };
}
