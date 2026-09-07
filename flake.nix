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
    mkPackages = pkgs: lib.mapAttrs (_: dir: pkgs.callPackage dir {}) packageDirs;
    perSystem = sys.forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      inherit pkgs;
      packages = mkPackages pkgs;
    });
  in {
    # Consumer-facing: supported systems resolve, listed unsupported ones throw
    # a named error at selection. `checks` is NOT wrapped: flake check walks
    # every attribute and a throwing value would fail it.
    packages = sys.forAllSystemsWithThrow (system: perSystem.${system}.packages);

    overlays.default = final: _prev: mkPackages final;

    # Every package builds under `nix flake check` (which builds `checks`, not
    # `packages`), plus one derivation per bats guard.
    checks = sys.forAllSystems (system: let
      v = perSystem.${system};
      inherit (v) pkgs;
      guard = name:
        pkgs.runCommand "guard-${name}" {
          nativeBuildInputs = [pkgs.bats pkgs.git pkgs.python3];
          DECLARED = builtins.toJSON (builtins.attrNames packageDirs);
          CHECK_ATTRS = builtins.toJSON (builtins.attrNames v.packages);
        } ''
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
        package-list = guard "package-list";
        hash-registry = guard "hash-registry";
        charter = guard "charter";

        # `nix flake check` only shape-checks an overlay. This applies
        # overlays.default to a fresh nixpkgs, builds every listed package
        # through it, and asserts each out path equals the direct package.
        overlay = let
          overlaid = import nixpkgs {
            inherit system;
            overlays = [self.overlays.default];
          };
          viaOverlay = lib.mapAttrs (name: _: overlaid.${name}) packageDirs;
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
