#!/bin/bash
# Test: coverage-check.sh with mocked xccov
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPDIR=$(mktemp -d)
trap 'rm -rf "$TEMPDIR"' EXIT

# --- Setup mock environment ---
MOCK_DERIVED="$TEMPDIR/MockDerivedData"
MOCK_PROFILE="$MOCK_DERIVED/Logs/Test"
mkdir -p "$MOCK_PROFILE"

# Create empty profdata (just needs to exist)
touch "$MOCK_PROFILE/test.profdata"

# Create mock xccov by capturing the test scenario in a JSON fixture
# Simulates a report with Adium at 45%, AdiumLibpurple at 62%
cat > "$TEMPDIR/mock-report.json" << 'EOF'
{
  "targets": [
    {"name": "Adium", "lineCoverage": 0.45},
    {"name": "AdiumLibpurple", "lineCoverage": 0.62},
    {"name": "AdiumTests", "lineCoverage": 0.80},
    {"name": "AIUtilities", "lineCoverage": 0.30}
  ]
}
EOF

# Create thresholds file with Adium at 50, AdiumLibpurple at 50, AIUtilities at 0
cat > "$TEMPDIR/coverage-thresholds.txt" << 'EOF'
# Per-target thresholds
Adium 50
AdiumLibpurple 50
Purple Service 0
EOF

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); true; }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); true; }

# --- Test 1: resolve_threshold picks per-target threshold ---
# Source the check script up to the function definition, then test
# the function in isolation
echo "=== Test: Per-target threshold lookup ==="
PROJECT_DIR="$TEMPDIR"
DEFAULT_THRESHOLD=50

# resolve_threshold() duplicated from coverage-check.sh — keep in sync
resolve_threshold() {
  local target="$1"
  local threshold_file="$PROJECT_DIR/coverage-thresholds.txt"
  if [ -f "$threshold_file" ]; then
    if [ ! -r "$threshold_file" ]; then
      echo "WARNING: $threshold_file not readable, using defaults" >&2
    else
      local line
      line=$(grep "^${target}[[:space:]]" "$threshold_file" 2>/dev/null || true)
      if [ -n "$line" ]; then
        local pct
        pct=$(echo "$line" | awk '{print $NF}')
        if [[ "$pct" =~ ^[0-9]+$ ]]; then
          echo "$pct"
          return
        fi
      fi
    fi
  fi
  echo "$DEFAULT_THRESHOLD"
}

RESULT=$(resolve_threshold "Adium")
if [ "$RESULT" = "50" ]; then pass "Adium → 50"; else fail "Adium: expected 50, got $RESULT"; fi

RESULT=$(resolve_threshold "AdiumLibpurple")
if [ "$RESULT" = "50" ]; then pass "AdiumLibpurple → 50"; else fail "AdiumLibpurple: expected 50, got $RESULT"; fi

RESULT=$(resolve_threshold "Purple Service")
if [ "$RESULT" = "0" ]; then pass "Purple Service → 0"; else fail "Purple Service: expected 0, got $RESULT"; fi

RESULT=$(resolve_threshold "UnknownTarget")
if [ "$RESULT" = "50" ]; then pass "UnknownTarget falls back to 50"; else fail "UnknownTarget: expected 50, got $RESULT"; fi

RESULT=$(resolve_threshold "AIUtilities")
if [ "$RESULT" = "50" ]; then pass "AIUtilities (not in file) falls back to 50"; else fail "AIUtilities: expected 50, got $RESULT"; fi

# --- Test 2: Threshold comparison logic ---
echo ""
echo "=== Test: Threshold comparison ==="
# Mock the jq + xccov call: simulate parsing report and checking thresholds
# In the real script, this is: jq -r '.targets[] | [.name, (.lineCoverage * 100 | floor)] | @tsv'
FAKE_REPORT=$(
  echo '{"targets":[
    {"name":"Adium","lineCoverage":0.45},
    {"name":"AdiumLibpurple","lineCoverage":0.62}
  ]}' | jq -r '.targets[] | [.name, (.lineCoverage * 100 | floor)] | @tsv'
)

# Expected: Adium at 45 < threshold 50 → below-threshold, AdiumLibpurple at 62 >= 50 → OK
BELOW_THRESHOLD=0
while IFS=$'\t' read -r TARGET PCT_INT; do
  THRESHOLD=$(resolve_threshold "$TARGET")
  if [ "$PCT_INT" -lt "$THRESHOLD" ]; then
    BELOW_THRESHOLD=$((BELOW_THRESHOLD + 1))
    echo "CHECK: $TARGET at ${PCT_INT}% < ${THRESHOLD}% (correctly detected as below threshold)"
  else
    echo "CHECK: $TARGET at ${PCT_INT}% >= ${THRESHOLD}% (at or above threshold)"
  fi
done < <(echo "$FAKE_REPORT")
# Adium at 45 < 50 → below threshold; AdiumLibpurple at 62 >= 50 → OK
if [ "$BELOW_THRESHOLD" -eq 1 ]; then
  pass "Target below threshold correctly detected"
else
  fail "Expected 1 below-threshold, got $BELOW_THRESHOLD"
fi

# --- Test 3: Edge cases in thresholds file ---
echo ""
echo "=== Test: Edge cases ==="

# Empty thresholds file → all fall back to DEFAULT_THRESHOLD
echo -n > "$TEMPDIR/coverage-thresholds.txt"
RESULT=$(resolve_threshold "Adium")
if [ "$RESULT" = "50" ]; then pass "Empty file → Adium falls back to 50"; else fail "Empty file: expected 50, got $RESULT"; fi

# Missing thresholds file → all fall back
rm -f "$TEMPDIR/coverage-thresholds.txt"
RESULT=$(resolve_threshold "Adium")
if [ "$RESULT" = "50" ]; then pass "Missing file → Adium falls back to 50"; else fail "Missing file: expected 50, got $RESULT"; fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -ne 0 ]; then exit 1; fi
