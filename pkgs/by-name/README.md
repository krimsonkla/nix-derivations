# by-name

The layout is nixpkgs' `pkgs/by-name` convention: `<first two letters of the
name>/<name>/package.nix`, called with `callPackage`, so a package moves
upstream as a file move. The discovery half of that convention is deliberately
not used here. `pkgs/default.nix` is an explicit index, and every guard
enumerates against it, because a package list derived from walking this tree
would make both sides of the guards' counts come from one walk. Adding a
package means a directory here and an entry there; `tests/package-list.bats`
holds the two equal.
