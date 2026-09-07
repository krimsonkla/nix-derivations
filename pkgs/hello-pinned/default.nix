{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "hello-pinned";
  version = "0-unstable-7fd1a60";
  src = fetchFromGitHub {
    owner = "octocat";
    repo = "Hello-World";
    rev = "7fd1a60b01f91b314f59955a4e4d4e80d8edf11d";
    hash = "sha256-gdkPz7VJ8ZOwJ5oetnuXBXPkkHlOsU7w0PghYjWgpAo=";
  };
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/hello-pinned
    cp README $out/share/hello-pinned/README
  '';
  meta = {
    description = "Placeholder package that exercises fetchFromGitHub, the guards, flake check, cachix push and substitute-only";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux" "aarch64-darwin"];
  };
}
