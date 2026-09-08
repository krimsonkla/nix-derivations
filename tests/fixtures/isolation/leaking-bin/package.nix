# Red fixture: a cli whose bin/ also carries its interpreter.
{
  stdenvNoCC,
  babashka,
}:
stdenvNoCC.mkDerivation {
  pname = "leaking-bin";
  version = "0";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/bin
    ln -s ${babashka}/bin/bb $out/bin/bb
    printf '#!/bin/sh\necho ok\n' > $out/bin/leaking-bin && chmod +x $out/bin/leaking-bin
  '';
  passthru = {
    kind = "cli";
    bins = ["leaking-bin"];
    smoke.leaking-bin = [[]];
    runtime = "shell";
  };
}
