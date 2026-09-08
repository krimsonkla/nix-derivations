# EXPLICIT package list. The directory layout follows nixpkgs' by-name
# convention (pkgs/by-name/<first two letters>/<name>/package.nix) so a
# package can move upstream as a file move; by-name's tree-walk discovery is
# NOT adopted, because a list derived from the same walk the guards check
# would make both sides of every count come from one enumeration. Adding a
# package means adding its directory AND an entry here.
#
# Each entry names the file, the package's kind (cli or library) and, for a
# library, the language set it extends. The guard in tests/isolation.bats
# asserts these equal the package's own passthru declarations.
{
  knot = {
    path = ./by-name/kn/knot/package.nix;
    kind = "cli";
  };
}
