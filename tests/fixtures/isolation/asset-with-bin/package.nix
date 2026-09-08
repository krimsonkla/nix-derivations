# Red fixture: an asset that puts a command on PATH.
{runCommand}:
runCommand "asset-with-bin" {
  passthru = {
    kind = "asset";
    files = ["refs/main"];
  };
} ''
  mkdir -p $out/refs $out/bin
  echo 0000 > $out/refs/main
  printf '#!/bin/sh\necho leak\n' > $out/bin/asset-with-bin && chmod +x $out/bin/asset-with-bin
''
