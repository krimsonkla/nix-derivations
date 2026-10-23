#!/usr/bin/env bats
# Consumer-nixpkgs guard. consumer-nixpkgs.txt names the nixpkgs each consumer
# pins, and the publish workflow builds every package against each of them,
# inside a job that holds the cache's write token. So the list is validated
# here and again by the same script at every point of use: shape, an
# owner/repo allowlist, and a 40-char rev. The provenance half needs the
# network; its failure arms run against loopback endpoints, never the
# internet. Counts are printed and pinned per the enumeration convention.

bats_require_minimum_version 1.5.0

setup() {
  load lib.sh
  ROOT=$(repo_root)
  SCRIPT="$ROOT/scripts/consumer-nixpkgs.py"
  LIST="$ROOT/consumer-nixpkgs.txt"
  TEST_TMPDIR=$(mktemp -d -p "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR unset}")
  GOOD_REF="github:cachix/devenv-nixpkgs/760b85220489f69855e6df78a6d1dad5873f8bf6"
}

teardown() {
  if [[ -n "${STUB_PID:-}" ]]; then kill "$STUB_PID" 2>/dev/null || true; fi
  rm -rf "$TEST_TMPDIR"
}

# Starts a loopback HTTP server answering every GET with the given HTTP status
# and a JSON body {"status": <compare status>}, and sets STUB_URL to its base
# URL. Port 0 lets the kernel pick a free port; the
# server writes the port it got to a file the helper waits for. Called
# directly, never inside $(...): a background child holding the substitution's
# stdout would keep it open, and the caller would wait forever.
start_stub() {
  local status="$1" compare="${2:-}" headers="${3:-}" portfile="$TEST_TMPDIR/port"
  python3 -c '
import http.server, sys
status, compare, headers, portfile = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
hits = portfile + ".hits"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        open(hits, "a").write("hit\n")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        for h in filter(None, headers.split(";")):
            k, v = h.split(":", 1)
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(("{\"status\": \"%s\"}" % compare).encode())
    def log_message(self, *a):
        pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(srv.server_address[1]))
srv.serve_forever()
' "$status" "$compare" "$headers" "$portfile" </dev/null >/dev/null 2>&1 &
  STUB_PID=$!
  local tries=50
  while [[ ! -s "$portfile" ]] && ((tries-- > 0)); do
    sleep 0.1
  done
  [[ -s "$portfile" ]] || return 1
  STUB_URL="http://127.0.0.1:$(cat "$portfile")"
}

@test "consumer-nixpkgs: the list validates" {
  run --separate-stderr python3 "$SCRIPT" validate "$LIST"
  echo "$stderr"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"refs validated from $LIST"* ]]
  [[ "$output" == *"layers $GOOD_REF"* ]]
}

@test "consumer-nixpkgs: count pin" {
  # One line per consumer; a consumer's bump replaces its own line, so this
  # moves only when a consumer is added or removed.
  n=$(python3 "$SCRIPT" validate "$LIST" 2>/dev/null | grep -c .)
  echo "consumer-nixpkgs: $n refs"
  [ "$n" -eq 1 ]
}

@test "consumer-nixpkgs: red -- an owner off the allowlist fails naming the line" {
  printf '# header\nlayers %s\nfork github:someone/nixpkgs/%s\n' "$GOOD_REF" "$(printf 'a%.0s' {1..40})" >"$TEST_TMPDIR/list"
  run --separate-stderr python3 "$SCRIPT" validate "$TEST_TMPDIR/list"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"list:3:"* ]]
  [[ "$stderr" == *"allowlist"* ]]
}

@test "consumer-nixpkgs: red -- a duplicate label fails" {
  printf 'layers %s\nlayers %s\n' "$GOOD_REF" "$GOOD_REF" >"$TEST_TMPDIR/list"
  run --separate-stderr python3 "$SCRIPT" validate "$TEST_TMPDIR/list"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"list:2:"*"duplicate label"* ]]
}

@test "consumer-nixpkgs: red -- a short rev fails" {
  printf 'layers github:cachix/devenv-nixpkgs/760b852\n' >"$TEST_TMPDIR/list"
  run --separate-stderr python3 "$SCRIPT" validate "$TEST_TMPDIR/list"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"list:1:"* ]]
}

@test "consumer-nixpkgs: red -- a missing list fails" {
  run --separate-stderr python3 "$SCRIPT" validate "$TEST_TMPDIR/absent"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"absent"* ]]
}

@test "consumer-nixpkgs: red -- a bad line leaves stdout empty" {
  printf 'layers %s\nbad github:cachix/devenv-nixpkgs/xyz\n' "$GOOD_REF" >"$TEST_TMPDIR/list"
  run --separate-stderr python3 "$SCRIPT" validate "$TEST_TMPDIR/list"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "consumer-nixpkgs: red -- an unreachable API fails provenance closed" {
  # Port 9 (discard) on loopback refuses the connection.
  run --separate-stderr env CONSUMER_NIXPKGS_API=http://127.0.0.1:9 CONSUMER_NIXPKGS_RETRIES=1 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"consumer-nixpkgs.txt:"* ]]
}

@test "consumer-nixpkgs: red -- an API answering 403 fails provenance closed" {
  start_stub 403 "" ""
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=1 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"403"* ]]
}

# The reachability rule itself: only behind or identical passes. A fork commit
# reads as diverged and a commit past the branch tip as ahead; both must fail,
# or a looser rule would pass every network-failure red above.
@test "consumer-nixpkgs: provenance accepts a rev the branch is behind" {
  start_stub 200 behind
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=1 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 0 ]
  [[ "$output" == *"layers $GOOD_REF"* ]]
}

@test "consumer-nixpkgs: red -- a diverged rev fails provenance" {
  start_stub 200 diverged
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=1 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"rolling=diverged"* ]]
}

@test "consumer-nixpkgs: red -- an ahead rev fails provenance" {
  start_stub 200 ahead
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=1 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"rolling=ahead"* ]]
}

@test "consumer-nixpkgs: a rate-limited 403 is retried, then fails closed" {
  start_stub 403 "" "Retry-After:0"
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=2 \
    python3 "$SCRIPT" provenance "$LIST"
  echo "$stderr"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(grep -c hit "$TEST_TMPDIR/port.hits")" -eq 2 ]
}

@test "consumer-nixpkgs: a plain 403 is not retried" {
  start_stub 403 "" ""
  run --separate-stderr env CONSUMER_NIXPKGS_API="$STUB_URL" CONSUMER_NIXPKGS_RETRIES=3 \
    python3 "$SCRIPT" provenance "$LIST"
  [ "$status" -eq 1 ]
  [ "$(grep -c hit "$TEST_TMPDIR/port.hits")" -eq 1 ]
}
