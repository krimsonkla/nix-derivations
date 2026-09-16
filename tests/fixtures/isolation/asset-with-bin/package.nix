# Red fixture: an asset that puts a command on PATH.
{runCommand}:
runCommand "asset-with-bin" {
  passthru = {
    kind = "asset";
    files = ["refs/main"];
  };
} "source ${./scripts/build.sh}"
