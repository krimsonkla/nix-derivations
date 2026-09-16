#!/usr/bin/env python3
"""Report shell embedded in a package expression.

A package expression declares a package; it does not carry the shell that
builds one. Every phase is a single `source ${./scripts/<name>.sh}` and the
script lives in the expression's own `scripts/` directory, where shellcheck
reads it, an editor highlights it, and bash quoting means what bash says
rather than what survives Nix string escaping.

Usage: scan-nix-shell.py <file.nix>... — one violation per line as
`<file>:<line>\t<kind>\t<detail>`, then a count line. Exit 1 when any
violation was found, 0 when none were, 64 on a usage error. The parser is
line-anchored, like the inventory scanner: an attribute and its value must
share a line to be judged.
"""

import re
import sys
from pathlib import Path

# Attributes stdenv runs as shell. `buildCommand` covers runCommand, whose
# body is the third argument rather than an attribute, so it is matched as a
# bare string too (see BARE_BODY_RE).
SHELL_ATTRS = (
    "unpackPhase patchPhase configurePhase buildPhase checkPhase "
    "installPhase installCheckPhase fixupPhase distPhase "
    "preUnpack postUnpack prePatch postPatch preConfigure postConfigure "
    "preBuild postBuild preCheck postCheck preInstall postInstall "
    "preInstallCheck postInstallCheck preFixup postFixup preDist postDist "
    "shellHook buildCommand"
).split()

ATTR_RE = re.compile(
    r"^\s*(?P<attr>" + "|".join(SHELL_ATTRS) + r")\s*=\s*(?P<value>.*?);?\s*$"
)
# The one permitted value, in either position: a reference to a .sh file under
# this expression's own scripts/ directory.
ALLOWED_RE = re.compile(r'^"source \$\{\./scripts/(?P<script>[A-Za-z0-9._-]+\.sh)\}"$')
# runCommand's body: a trailing string argument that is not an attribute.
BARE_BODY_RE = re.compile(r'^\s*\}\s*(?P<value>"[^"]*")\s*$')
INDENTED_STRING = "''"


def scan(path: Path):
    """Yield (line number, kind, detail) for each violation in one file."""
    text = path.read_text()
    for number, line in enumerate(text.splitlines(), start=1):
        if INDENTED_STRING in line:
            # An indented string is the shape a shell body takes in Nix, and
            # a package expression has no other use for one. Reported on the
            # opening line: the body below it is the violation's content, not
            # a second violation.
            yield number, "indented-string", line.strip()
            continue

        match = ATTR_RE.match(line) or BARE_BODY_RE.match(line)
        if not match:
            continue
        value = match.group("value")
        attr = match.groupdict().get("attr") or "buildCommand"
        allowed = ALLOWED_RE.match(value)
        if not allowed:
            yield number, "inline-shell", f"{attr} = {value}"
            continue
        script = path.parent / "scripts" / allowed.group("script")
        if not script.is_file():
            yield number, "missing-script", str(script)


def main(argv):
    if len(argv) < 2:
        print(f"usage: {argv[0]} <file.nix>...", file=sys.stderr)
        return 64
    files = [Path(a) for a in argv[1:]]
    for f in files:
        if not f.is_file():
            print(f"not a file: {f}", file=sys.stderr)
            return 2

    violations = 0
    for f in files:
        for number, kind, detail in scan(f):
            violations += 1
            print(f"{f}:{number}\t{kind}\t{detail}")
    print(f"nix-shell-scan: {len(files)} expressions scanned, {violations} violations found")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
