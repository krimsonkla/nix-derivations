# The supported system set is a visible literal by design: a wrong entry here
# is a readable diff, not a silent derivation.
{lib}: let
  systems = ["x86_64-linux" "aarch64-darwin"];
  # Systems a consumer is likely to evaluate from without being supported.
  # Each gets a throwing value so `packages.<system>` yields a named error at
  # selection time instead of an attribute-missing failure in their flake.
  # (`__functor` would only fire on application, never on selection, and a
  # function-valued attribute in `checks` is rejected by `nix flake check`.)
  # Accepted residual: `nix flake show` and `--all-systems` evaluate these
  # throws; any system not listed here still gets plain attribute-missing.
  unsupported = ["x86_64-darwin" "aarch64-linux"];
  unsupportedMsg = s: "nix-derivations: unsupported system ${s}; supported: ${lib.concatStringsSep ", " systems}";
in {
  inherit systems;
  forAllSystems = f: lib.genAttrs systems f;
  # For consumer-facing outputs (packages, devShells, formatter): supported
  # systems map through f, listed unsupported systems throw by name.
  forAllSystemsWithThrow = f:
    lib.genAttrs systems f
    // lib.genAttrs unsupported (s: throw (unsupportedMsg s));
}
