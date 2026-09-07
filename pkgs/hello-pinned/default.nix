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
    rev = "553c2077f0edc3d5dc5d17262f6aa498e69d6f8e";
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
