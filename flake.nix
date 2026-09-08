{
  description = "Shared Nix derivations pinned by every krimsonkla repo";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
  }: let
    inherit (nixpkgs) lib;
    sys = import ./lib/systems.nix {inherit lib;};
    packageDirs = import ./pkgs;
    isolation = import ./lib/isolation.nix {inherit lib;};
    # A library is built with the interpreter of the set it extends, never at
    # top level; a cli with the top-level callPackage. Both take the index as
    # an argument so the fixture checks can run over an extended one.
    familyOf = e: let
      fam = isolation.familyOfSet e.set;
    in
      assert lib.assertMsg (fam != null) "nix-derivations: no family provides the set ${e.set}; add a row to lib/isolation.nix";
        isolation.families.${fam};
    mkPackagesFrom = index: pkgs:
      lib.mapAttrs (_: e:
        if e.kind == "library"
        then pkgs.${(familyOf e).interpreter}.pkgs.callPackage e.path {}
        else pkgs.callPackage e.path {})
      index;
    # Libraries land inside their set through the interpreter's own fixpoint:
    # override the interpreter with packageOverrides, pass self so the
    # interpreter's own package set resolves them, and pin the aliased set
    # explicitly. An attrset merge onto the set would leave the attribute
    # missing from `python3.pkgs` and from anything built with its callPackage.
    mkOverlay = index: final: prev: let
      clis = lib.filterAttrs (_: e: e.kind == "cli") index;
      libraries = lib.filterAttrs (_: e: e.kind == "library") index;
      byInterp = lib.groupBy (n: (familyOf libraries.${n}).interpreter) (lib.attrNames libraries);
    in
      lib.mapAttrs (_: e: final.callPackage e.path {}) clis
      // lib.concatMapAttrs (interp: names: let
        setName = (familyOf libraries.${lib.head names}).set;
        py = prev.${interp}.override {
          self = py;
          packageOverrides = pyfinal: _pyprev:
            lib.genAttrs names (n: pyfinal.callPackage libraries.${n}.path {});
        };
      in {
        ${interp} = py;
        ${setName} = py.pkgs;
      })
      byInterp;
    mkPackages = mkPackagesFrom packageDirs;
    perSystem = sys.forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      overlaid = import nixpkgs {
        inherit system;
        overlays = [(mkOverlay packageDirs)];
      };
    in {
      inherit pkgs overlaid;
      packages = mkPackages pkgs;
      manifest = isolation.manifest {
        index = packageDirs;
        packages = mkPackages pkgs;
        inherit overlaid;
      };
    });
  in {
    # Consumer-facing: supported systems resolve, listed unsupported ones throw
    # a named error at selection. `checks` is NOT wrapped: flake check walks
    # every attribute and a throwing value would fail it.
    packages = sys.forAllSystemsWithThrow (system: perSystem.${system}.packages);

    overlays.default = mkOverlay packageDirs;

    # Read by tests/isolation.bats outside a check derivation (inside one the
    # guard derivation exports the same values as environment variables).
    lib = {
      isolationFamilies = isolation.families;
      isolationManifest = sys.forAllSystems (system: perSystem.${system}.manifest);
    };

    # Every package builds under `nix flake check` (which builds `checks`, not
    # `packages`), plus one derivation per bats guard.
    checks = sys.forAllSystems (system: let
      v = perSystem.${system};
      inherit (v) pkgs;
      fixtureGuard = expect: fixture: entry: let
        idx = packageDirs // {${fixture} = entry;};
        # The wrong-set fixture is a python library whose passthru names a set
        # no family provides; the index says python3Packages so it can be
        # built at all, and the guard reports the passthru side.
        pk = v.packages // {${fixture} = (mkPackagesFrom idx pkgs).${fixture};};
        overlaidFixture = import nixpkgs {
          inherit system;
          overlays = [(mkOverlay idx)];
        };
        m = isolation.manifest {
          index = idx;
          packages = pk;
          overlaid = overlaidFixture;
        };
        families = toString (builtins.length (builtins.attrNames isolation.families));
      in
        pkgs.runCommand "isolation-${expect}-${fixture}" {
          nativeBuildInputs = [pkgs.bats pkgs.git pkgs.python3];
          ISOLATION_MANIFEST = builtins.toJSON m;
          FAMILIES = builtins.toJSON isolation.families;
          DECLARED = builtins.toJSON (builtins.attrNames idx);
          ISOLATION_PINS = "2 1 1 ${families} 2";
        } ''
          cp -r ${self} src && chmod -R u+w src && cd src
          git init -q && git config user.email guard@localhost && git config user.name guard && git add -A
          set +e; bats tests/isolation.bats >log 2>&1; rc=$?; set -e
          cat log
          if [ "${expect}" = green ]; then
            [ "$rc" -eq 0 ] || { echo "green check: the guard failed with fixture ${fixture}"; exit 1; }
            echo "isolation-green-${fixture}: library branch green" | tee $out
          else
            [ "$rc" -ne 0 ] || { echo "red check: the guard passed with fixture ${fixture}"; exit 1; }
            grep -q '${fixture}' log
            echo "isolation-red-${fixture}: refused by name" | tee $out
          fi
        '';
      guard = name: extra:
        pkgs.runCommand "guard-${name}" ({
            nativeBuildInputs = [pkgs.bats pkgs.git pkgs.python3];
            DECLARED = builtins.toJSON (builtins.attrNames packageDirs);
            CHECK_ATTRS = builtins.toJSON (builtins.attrNames v.packages);
          }
          // extra) ''
          set -o pipefail
          cp -r ${self} src && chmod -R u+w src && cd src
          git init -q && git config user.email guard@localhost && git config user.name guard && git add -A
          # pipefail makes a failing bats fail the derivation even though tee
          # succeeds; without it a red guard would build green.
          bats tests/${name}.bats 2>&1 | tee $out
        '';
    in
      v.packages
      // {
        package-list = guard "package-list" {};
        hash-registry = guard "hash-registry" {};
        charter = guard "charter" {};
        named-labels = guard "named-labels" {};
        inventory = guard "inventory" {};
        isolation = guard "isolation" {
          ISOLATION_MANIFEST = builtins.toJSON v.manifest;
          FAMILIES = builtins.toJSON isolation.families;
        };

        # The isolation guard over the index plus one fixture. A red passes
        # only when bats fails naming the fixture; the green (a trivial python
        # library) passes when the library branch is green with the fixture
        # counted, and proves the overlay places a library for real.
        isolation-library-green = fixtureGuard "green" "fixture-lib" {
          path = ./tests/fixtures/isolation/fixture-lib/package.nix;
          kind = "library";
          set = "python3Packages";
        };
        isolation-red-leak = fixtureGuard "red" "leaking-bin" {
          path = ./tests/fixtures/isolation/leaking-bin/package.nix;
          kind = "cli";
        };
        isolation-red-unkinded = fixtureGuard "red" "unkinded" {
          path = ./tests/fixtures/isolation/unkinded/package.nix;
          kind = "cli";
        };
        isolation-red-missing-subject = fixtureGuard "red" "missing-subject" {
          path = ./tests/fixtures/isolation/missing-subject/package.nix;
          kind = "cli";
        };
        isolation-red-misdeclared-runtime = fixtureGuard "red" "misdeclared-runtime" {
          path = ./tests/fixtures/isolation/misdeclared-runtime/package.nix;
          kind = "cli";
        };
        isolation-red-unknown-family = fixtureGuard "red" "unknown-family" {
          path = ./tests/fixtures/isolation/unknown-family/package.nix;
          kind = "cli";
        };
        isolation-red-wrong-set = fixtureGuard "red" "wrong-set" {
          path = ./tests/fixtures/isolation/wrong-set/package.nix;
          kind = "library";
          set = "python3Packages";
        };

        # The same require-all.clj the knot build runs, over a fixture holding
        # one namespace that requires a library babashka does not bundle. The
        # check passes only when the form exits non-zero naming that library,
        # so the build-time check cannot rot into a claim.
        knot-namespace-check-red = pkgs.runCommand "knot-namespace-check-red" {nativeBuildInputs = [pkgs.babashka];} ''
          fixture=${./tests/fixtures/unbundled-require}
          set +e
          bb --classpath "$fixture" ${./pkgs/by-name/kn/knot/require-all.clj} "$fixture" >log 2>&1
          rc=$?
          set -e
          cat log
          [ "$rc" -ne 0 ] || { echo "red check: require-all.clj passed over the unbundled fixture"; exit 1; }
          grep -q 'clj_http/client' log
          echo "knot-namespace-check-red: 1 unbundled namespace refused" | tee $out
        '';

        # `nix flake check` only shape-checks an overlay. This applies
        # overlays.default to a fresh nixpkgs, builds every listed package
        # through it, and asserts each out path equals the direct package.
        overlay = let
          inherit (v) overlaid;
          viaOverlay = lib.mapAttrs (name: e:
            if e.kind == "library"
            then overlaid.${(familyOf e).set}.${name}
            else overlaid.${name})
          packageDirs;
          direct = v.packages;
          mismatches = lib.filterAttrs (n: p: "${p}" != "${direct.${n}}") viaOverlay;
        in
          assert lib.assertMsg (mismatches == {}) "overlay check: out paths differ for ${lib.concatStringsSep ", " (lib.attrNames mismatches)}";
            pkgs.linkFarm "overlay-check" (lib.mapAttrsToList (n: p: {
                name = n;
                path = p;
              })
              viaOverlay);

        pre-commit = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            statix.enable = true;
            deadnix.enable = true;
            shellcheck.enable = true;
            bats-guards = {
              enable = true;
              name = "bats guards";
              # The guards need a git worktree and nix. Inside the pre-commit
              # check derivation the source is a plain copy, so the hook skips
              # there with a message; the same guards run as their own check
              # derivations under `checks`, which is where CI enforces them.
              entry = "${pkgs.writeShellScript "bats-guards" ''
                if ! git rev-parse --show-toplevel >/dev/null 2>&1 || ! command -v nix >/dev/null 2>&1; then
                  echo "bats guards: skipped outside a git worktree with nix (enforced as flake checks)"
                  exit 0
                fi
                exec ${pkgs.bats}/bin/bats tests/
              ''}";
              language = "system";
              pass_filenames = false;
              files = "^(pkgs/|tests/|README\\.md|CONTRIBUTING\\.md|LICENSE)";
            };
          };
        };
      });

    devShells = sys.forAllSystems (system: let
      pkgs = perSystem.${system}.pkgs;
    in {
      default = pkgs.mkShell {
        packages =
          [pkgs.alejandra pkgs.statix pkgs.deadnix pkgs.bats pkgs.nix-prefetch-github pkgs.prefetch-npm-deps]
          ++ self.checks.${system}.pre-commit.enabledPackages;
        inherit (self.checks.${system}.pre-commit) shellHook;
      };
    });

    formatter = sys.forAllSystems (system: perSystem.${system}.pkgs.alejandra);
  };
}
