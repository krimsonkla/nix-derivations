#!/usr/bin/env python3
"""Validate consumer-nixpkgs.txt, and check that each rev comes from upstream.

The publish workflow builds every package against each listed nixpkgs inside
the job that holds the cache's write token, so every caller reads the list
through this script and nothing else.

Usage:
  consumer-nixpkgs.py validate <file>
  consumer-nixpkgs.py provenance <file>

Both print the accepted entries on stdout, one `<label> <flake-ref>` per
line, and only after every entry has passed: a failure prints nothing on
stdout, so a caller that loses the exit status cannot hand a partial list to
a build. The count and the file go to stderr. Exit 0 when every entry passed,
1 when any failed (stderr names the file and line), 64 on a usage error.

validate checks the shape: `<label> github:<owner>/<repo>/<40 hex>`, unique
labels, and an owner/repo on ALLOWED. provenance runs validate, then asks the
GitHub compare API whether each rev is reachable from one of its repository's
upstream branches. GitHub serves a fork's commit through the parent's path, so
the allowlist alone does not prove where a rev came from. A network error or a
5xx/429 answer, or a 403 that GitHub marks as rate limiting, is retried; anything else that is not a definite "reachable"
fails. CONSUMER_NIXPKGS_API overrides the API base, CONSUMER_NIXPKGS_RETRIES
the attempt count, and GITHUB_TOKEN, when set, authenticates the calls to
https://api.github.com (and only there).
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# owner/repo -> the upstream branches a listed rev must be reachable from,
# tried in order. The branches live here, never in the list, so an entry
# cannot name its own proof.
ALLOWED = {
    "cachix/devenv-nixpkgs": ("rolling",),
    "NixOS/nixpkgs": ("nixos-unstable", "master"),
}

LABEL_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
REF_RE = re.compile(r"^github:([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/([0-9a-f]{40})$")
REACHABLE = ("behind", "identical")
TRANSIENT = (429, 500, 502, 503, 504)
RATE_LIMIT_CAP = 60


class ListError(Exception):
    """A line or the file itself failed validation."""


def parse(path):
    """Return [(label, ref, owner_repo, rev, lineno)] or raise ListError naming the line."""
    p = Path(path)
    try:
        lines = p.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise ListError(f"{path}: cannot read the list: {exc.strerror}") from exc
    entries, labels = [], set()
    for n, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 2:
            raise ListError(f"{p.name}:{n}: expected '<label> <flake-ref>', got {len(fields)} fields")
        label, ref = fields
        if not LABEL_RE.match(label):
            raise ListError(f"{p.name}:{n}: label {label!r} must match {LABEL_RE.pattern}")
        if label in labels:
            raise ListError(f"{p.name}:{n}: duplicate label {label!r}; each consumer has one line, replaced on a bump")
        m = REF_RE.match(ref)
        if not m:
            raise ListError(f"{p.name}:{n}: ref {ref!r} must be github:<owner>/<repo>/<40 hex rev>")
        owner_repo = f"{m.group(1)}/{m.group(2)}"
        if owner_repo not in ALLOWED:
            raise ListError(f"{p.name}:{n}: {owner_repo} is not on the allowlist ({', '.join(ALLOWED)})")
        labels.add(label)
        entries.append((label, ref, owner_repo, m.group(3), n))
    if not entries:
        raise ListError(f"{path}: the list holds no entries")
    return entries


def rate_limit_wait(exc):
    """Seconds to wait when a 403 or 429 is GitHub rate limiting, else None.

    GitHub answers a primary or secondary rate limit with 403 (or 429) plus
    Retry-After or x-ratelimit-remaining: 0. That is transient; any other 403
    is a refusal and fails at once. The wait is capped so a long reset fails
    the run instead of holding a runner.
    """
    if exc.code not in (403, 429):
        return None
    headers = exc.headers or {}
    retry_after = headers.get("Retry-After")
    if retry_after is not None:
        try:
            return min(max(int(retry_after), 0), RATE_LIMIT_CAP)
        except ValueError:
            return RATE_LIMIT_CAP
    if headers.get("x-ratelimit-remaining") == "0":
        try:
            return min(max(int(headers.get("x-ratelimit-reset", "0")) - int(time.time()), 0), RATE_LIMIT_CAP)
        except ValueError:
            return RATE_LIMIT_CAP
    return None


def compare(api, owner_repo, branch, rev, token, attempts):
    """Return the compare status string, or raise ListError after the last attempt."""
    url = f"{api}/repos/{owner_repo}/compare/{branch}...{rev}"
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    last = ""
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp).get("status", "")
        except urllib.error.HTTPError as exc:
            last = f"HTTP {exc.code}"
            if exc.code == 404:
                return "absent"
            wait = rate_limit_wait(exc)
            if exc.code not in TRANSIENT and wait is None:
                break
            if attempt < attempts:
                time.sleep(wait if wait is not None else 2**attempt)
            continue
        except (urllib.error.URLError, OSError, ValueError) as exc:
            last = f"network error: {getattr(exc, 'reason', exc)}"
        if attempt < attempts:
            time.sleep(2**attempt)
    raise ListError(f"compare {owner_repo} {branch}...{rev} failed: {last}")


def provenance(entries, path):
    api = os.environ.get("CONSUMER_NIXPKGS_API", "https://api.github.com").rstrip("/")
    # The token goes only to GitHub itself: an overridden API base (the test
    # stubs) never receives it.
    token = os.environ.get("GITHUB_TOKEN", "") if api == "https://api.github.com" else ""
    try:
        attempts = max(1, int(os.environ.get("CONSUMER_NIXPKGS_RETRIES", "3")))
    except ValueError:
        attempts = 3
    name = Path(path).name
    for label, _ref, owner_repo, rev, n in entries:
        seen = []
        for branch in ALLOWED[owner_repo]:
            try:
                status = compare(api, owner_repo, branch, rev, token, attempts)
            except ListError as exc:
                raise ListError(f"{name}:{n}: {label}: {exc}") from exc
            if status in REACHABLE:
                break
            seen.append(f"{branch}={status or 'unknown'}")
        else:
            raise ListError(f"{name}:{n}: {label}: {rev} is not reachable from {owner_repo} upstream ({', '.join(seen)})")


def main(argv):
    if len(argv) != 3 or argv[1] not in ("validate", "provenance"):
        print("usage: consumer-nixpkgs.py validate|provenance <file>", file=sys.stderr)
        return 64
    mode, path = argv[1], argv[2]
    try:
        entries = parse(path)
        if mode == "provenance":
            provenance(entries, path)
    except ListError as exc:
        print(f"consumer-nixpkgs: {exc}", file=sys.stderr)
        return 1
    for label, ref, *_ in entries:
        print(f"{label} {ref}")
    if mode == "validate":
        print(f"consumer-nixpkgs: {len(entries)} refs validated from {path} (allowlist: {', '.join(ALLOWED)})", file=sys.stderr)
    else:
        print(f"consumer-nixpkgs: {len(entries)} refs validated from {path} and reachable from upstream", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
