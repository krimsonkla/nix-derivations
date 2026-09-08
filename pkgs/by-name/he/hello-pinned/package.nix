{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "hello-pinned";
  version = "0-unstable-553c207";
  src = fetchFromGitHub {
    owner = "octocat";
    repo = "Hello-World";
    rev = "553c2077f0edc3d5dc5d17262f6aa498e69d6f8e";
    hash = "sha256-MX8NoLcpWg4XRjR8LZp/bTZ2Pjg2FMnIrr+jipdDXB8=";
  };
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/hello-pinned
    cp README $out/share/hello-pinned/README
  '';
  passthru = {
    kind = "cli";
    bins = [];
    smoke = {};
    runtime = "none";
  };
  meta = {
    description = "Placeholder package that exercises fetchFromGitHub, the guards, flake check, cachix push and substitute-only";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux" "aarch64-darwin"];
  };
}
