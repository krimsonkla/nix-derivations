#!/usr/bin/env python3
# pylint: disable=invalid-name  # the script name is a command name, hyphenated like the others under scripts/
"""Inventory hand-packaged derivations across local checkouts.

Walks each checkout's tracked .nix files and reports every builder,
override or fetcher call on a third-party source, with the package name,
version and pin where the surrounding block declares them. The first line
is `inventory-kinds: <comma-separated names>`, the builders and fetchers the
scan recognises, so a consumer can detect a scope change. Then one
tab-separated row per finding and a final count line naming the number of
checkouts scanned and rows found, so an empty enumeration is visible.

Usage: inventory-derivations.py [--tsv|--markdown] <checkout>...
Exit 0 on success, 2 when a checkout is not a git worktree, 64 on usage.
"""

import re
import subprocess
import sys
from pathlib import Path

BUILDERS = (
    "buildNpmPackage",
    "buildGoModule",
    "buildPythonPackage",
    "buildPythonApplication",
    "mkDerivation",
    "overrideAttrs",
    "overridePythonAttrs",
)
FETCHERS = (
    "fetchFromGitHub",
    "fetchFromGitLab",
    "fetchurl",
    "fetchzip",
    "fetchgit",
    "fetchPypi",
    "fetchTarball",
)
CALL_RE = re.compile(
    r"\b(?P<kind>" + "|".join(BUILDERS + FETCHERS) + r")\b\s*(?:rec\s*)?[{(]"
)
ATTR_KEYS = "pname|name|version|rev|owner|repo|url|hash|sha256|npmDepsHash|vendorHash|outputHash"
ATTR_RE = re.compile(r"^\s*(?P<key>" + ATTR_KEYS + r')\s*=\s*"?(?P<val>[^";]*)"?\s*;')
BLOCK_LOOKAHEAD = 60
# A builder call this far above another call, at a shallower indent, owns
# it: a fetcher is that builder's src, and a nested override is part of the
# outer one, so neither is a finding of its own.
ENCLOSING_LOOKBACK = 80
# A name or version declared in an enclosing let-binding this far above the
# call, when the block itself declares none.
SCOPE_LOOKBACK = 30
# Declarations that pass a builder in as a function argument or alias
# ("buildPythonPackage,", "fetchPypi = self.fetchPypi;") are not calls.
ARG_RE = re.compile(r"^\s*(" + "|".join(BUILDERS + FETCHERS) + r")\s*[,=]")


def tracked_nix_files(checkout: Path):
    """Tracked .nix files of a checkout, as absolute paths."""
    out = subprocess.run(
        ["git", "-C", str(checkout), "ls-files", "--", "*.nix"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return [checkout / p for p in out.splitlines() if p]


def indent(line: str) -> int:
    """Leading-space count."""
    return len(line) - len(line.lstrip(" "))


def block_attrs(lines, start):
    """Attributes declared inside the block opened at lines[start]."""
    base = indent(lines[start])
    found = {}
    for j in range(start + 1, min(len(lines), start + BLOCK_LOOKAHEAD)):
        line = lines[j]
        if line.strip() and indent(line) <= base:
            break
        m = ATTR_RE.match(line)
        if m and m.group("key") not in found:
            found[m.group("key")] = m.group("val").strip()
    return found


def enclosed_by_builder(lines, i):
    """True when a builder call at a shallower indent sits within the lookback above line i."""
    base = indent(lines[i])
    for j in range(i - 1, max(-1, i - ENCLOSING_LOOKBACK), -1):
        m = CALL_RE.search(lines[j])
        if m and m.group("kind") in BUILDERS and indent(lines[j]) < base:
            return True
    return False


def scan_file(
    checkout: Path, path: Path
):  # pylint: disable=too-many-locals,too-many-branches
    """One row per line carrying a builder, override or fetcher call not owned by a builder."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    rows = []
    for i, line in enumerate(lines):
        if line.lstrip().startswith("#") or ARG_RE.match(line):
            continue
        m = CALL_RE.search(line)
        if not m:
            continue
        kind = m.group("kind")
        if enclosed_by_builder(lines, i):
            continue
        attrs = block_attrs(lines, i)
        for key in ("pname", "version"):
            if key not in attrs:
                for j in range(i - 1, max(-1, i - SCOPE_LOOKBACK), -1):
                    sm = ATTR_RE.match(lines[j])
                    if sm and sm.group("key") == key:
                        attrs[key] = sm.group("val").strip()
                        break
        # The attribute set the override or derivation is applied to names the
        # package when the block itself does not: "foo = prev.foo.overrideAttrs".
        # A bare fetcher is named by what it fetches.
        name = attrs.get("pname") or attrs.get("name")
        if not name:
            lhs = re.match(r"^\s*([A-Za-z0-9_-]+)\s*=", line)
            dotted = re.search(r"([A-Za-z0-9_-]+)\." + kind, line)
            if kind in FETCHERS and attrs.get("url"):
                name = attrs["url"].rsplit("/", 1)[-1]
            elif lhs and lhs.group(1) != "src":
                name = lhs.group(1)
            elif dotted:
                name = dotted.group(1)
            else:
                name = "?"
        pin = (
            attrs.get("rev")
            or attrs.get("hash")
            or attrs.get("sha256")
            or attrs.get("npmDepsHash")
            or attrs.get("vendorHash")
            or attrs.get("outputHash")
            or ""
        )
        source = attrs.get("url") or (
            f"{attrs['owner']}/{attrs['repo']}"
            if "owner" in attrs and "repo" in attrs
            else ""
        )
        rows.append(
            {
                "repo": checkout.name,
                "path": f"{path.relative_to(checkout)}:{i + 1}",
                "kind": kind,
                "package": name,
                "version": attrs.get("version", ""),
                "source": source,
                "pin": pin[:16],
            }
        )
    return rows


def main(argv):
    """Parse --tsv/--markdown and checkouts, scan, print rows and the count line."""
    fmt = "tsv"
    args = []
    for a in argv:
        if a in ("--tsv", "--markdown"):
            fmt = a[2:]
        else:
            args.append(a)
    if not args:
        print(__doc__, file=sys.stderr)
        return 64
    rows = []
    for arg in args:
        checkout = Path(arg).resolve()
        if not (checkout / ".git").exists():
            print(f"inventory: {checkout} is not a git checkout", file=sys.stderr)
            return 2
        for f in tracked_nix_files(checkout):
            rows.extend(scan_file(checkout, f))
    cols = ["repo", "path", "kind", "package", "version", "source", "pin"]
    print("inventory-kinds: " + ",".join(BUILDERS + FETCHERS))
    if fmt == "markdown":
        print("| " + " | ".join(cols) + " |")
        print("|" + "---|" * len(cols))
        for r in rows:
            print("| " + " | ".join(f"`{r[c]}`" if r[c] else "" for c in cols) + " |")
    else:
        print("\t".join(cols))
        for r in rows:
            print("\t".join(r[c] for c in cols))
    print(f"inventory: {len(args)} checkouts scanned, {len(rows)} derivations found")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
