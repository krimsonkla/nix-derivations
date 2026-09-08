# Green fixture: an asset in a model-cache shape, the witness for the asset
# branch.
{runCommand}:
runCommand "fixture-asset" {
  passthru = {
    kind = "asset";
    files = ["refs/main" "blobs/0000"];
  };
} ''
  mkdir -p $out/refs $out/blobs
  echo 0000 > $out/refs/main
  echo data > $out/blobs/0000
''
