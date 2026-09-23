{
  lib,
  buildGoModule,
  fetchFromGitLab,
}: let
  # The rev is spent twice: once to fetch the source, once to stamp the binary.
  # They are the same value by construction rather than by a reviewer noticing,
  # because a binary stamped with a commit other than the one it was built from
  # resolves somebody else's container image.
  rev = "50516e8ccf85514a484295556f578f9d97437707";
in
  buildGoModule {
    pname = "glci";
    version = "0.8.0";
    src = fetchFromGitLab {
      group = "gitlab-org/ci-cd";
      owner = "runner-tools";
      repo = "glci";
      inherit rev;
      hash = "sha256-vlz75vm09jrtcMMobx51Lnj7sTtObBqHyeLCaBPoR9g=";
    };
    vendorHash = "sha256-XOpUoZGQy6eZxHIfi52Bfpwg5GKj0DUSPDG+vx02Hs4=";
    patches = [];

    # One command, so the other main packages under cmd/ and the e2e trees are
    # not built into outputs nobody declared.
    subPackages = ["cmd/glci"];

    # glci resolves the container image it runs jobs in by the commit it was
    # built from, and an unstamped binary is a dev build: it falls through to a
    # local image tag that exists on a maintainer's machine and nowhere else.
    # Stamping the pinned rev is what makes a consumer's glci find the image
    # published from the same source. The -X path must equal the module path,
    # which upstream's own TestBuildLDFlagsMatchModulePath pins.
    ldflags = [
      "-s"
      "-w"
      "-X gitlab.com/gitlab-org/ci-cd/runner-tools/glci/pkg/version.Commit=${rev}"
    ];

    # What the phase script needs from Nix: the same rev the fetch used, so the
    # check compares the binary's stamp against this derivation's own pin.
    pinnedRev = rev;

    # Sourced, not executed: runHook is a shell function of the build
    # environment, and a child process would not have it.
    doInstallCheck = true;
    installCheckPhase = "source ${./scripts/install-check.sh}";

    # Upstream's suite drives a container engine and a real daemon, neither of
    # which a sandboxed build has. What this package can prove without one is
    # proven in installCheckPhase instead.
    doCheck = false;

    passthru = {
      kind = "cli";
      bins = ["glci"];
      # Both vectors are upstream's own light commands: no daemon, no container
      # engine, and nothing read from the working directory, which the hostile
      # run moves.
      smoke.glci = [["version"] ["--help"]];
      runtime = "none";
    };

    meta = {
      description = "Run GitLab CI/CD pipelines locally";
      homepage = "https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci";
      license = lib.licenses.mit;
      mainProgram = "glci";
      platforms = ["x86_64-linux" "aarch64-darwin"];
    };
  }
