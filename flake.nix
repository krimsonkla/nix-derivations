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
    ...
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
        charter = guard "charter";
      });

    devShells = sys.forAllSystems (system: let
      pkgs = perSystem.${system}.pkgs;
    in {
      default = pkgs.mkShell {
        packages = [pkgs.alejandra pkgs.statix pkgs.deadnix pkgs.bats pkgs.nix-prefetch-github pkgs.prefetch-npm-deps];
      };
    });

    formatter = sys.forAllSystems (system: perSystem.${system}.pkgs.alejandra);
  };
}
