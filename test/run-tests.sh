#!/usr/bin/env bash
# Run scan.sh against each fixture dir, assert exit codes.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCAN="$ROOT/scan.sh"
FAIL=0

run_case() {
  local name="$1"
  local dir="$2"
  local expected="$3"

  pushd "$dir" >/dev/null
  bash "$SCAN" >/tmp/scan-out.txt 2>&1
  local rc=$?
  popd >/dev/null

  if [ "$rc" -eq "$expected" ]; then
    echo "PASS: $name (exit=$rc)"
  else
    echo "FAIL: $name expected exit=$expected got=$rc"
    cat /tmp/scan-out.txt
    FAIL=1
  fi
}

run_case_stdout() {
  local name="$1"
  local dir="$2"
  local expected="$3"
  local needle="$4"

  pushd "$dir" >/dev/null
  bash "$SCAN" >/tmp/scan-out.txt 2>&1
  local rc=$?
  popd >/dev/null

  if [ "$rc" -eq "$expected" ] && grep -q "$needle" /tmp/scan-out.txt; then
    echo "PASS: $name (exit=$rc, stdout matched '$needle')"
  else
    echo "FAIL: $name expected exit=$expected got=$rc needle='$needle'"
    cat /tmp/scan-out.txt
    FAIL=1
  fi
}

run_case "passing fixture" "$ROOT/test/fixtures/passing" 0
run_case "failing fixture" "$ROOT/test/fixtures/failing" 1
run_case_stdout "empty fixture" "$ROOT/test/fixtures/empty" 0 "PASS-EMPTY"

# Exemption test: drop a valid exempt file into failing fixture and re-run
EXEMPT_DIR="$(mktemp -d)"
cp "$ROOT/test/fixtures/failing/.env.example" "$EXEMPT_DIR/"
cat >"$EXEMPT_DIR/.gateway-exempt" <<'EOF'
This fixture intentionally lacks ANTHROPIC_BASE_URL.
It exists to verify the exemption code path in scan.sh.
Approved by @kdrake for test purposes only.
EOF
run_case "failing fixture WITH valid exemption" "$EXEMPT_DIR" 0
rm -rf "$EXEMPT_DIR"

exit $FAIL
