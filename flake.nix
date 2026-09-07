{
  description = "Shared Nix derivations pinned by every krimsonkla repo";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...}: let
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

    checks = sys.forAllSystems (system: perSystem.${system}.packages);

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
