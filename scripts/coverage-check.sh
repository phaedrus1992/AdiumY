#!/bin/bash
set -euo pipefail

# Coverage threshold check for Xcode test runs
# Reads xccov report and fails if any production target is below its threshold.
#
# Per-target thresholds are read from scripts/coverage-thresholds.txt
# (formatted as "target_name percentage" one per line). Targets not
# listed in that file fall back to the COVERAGE_THRESHOLD env var.
#
# Branch coverage is reported (not gated) per design doc §2.5.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

DEFAULT_THRESHOLD="${COVERAGE_THRESHOLD:-50}"
if ! [[ "$DEFAULT_THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: COVERAGE_THRESHOLD must be a positive integer, got: '$DEFAULT_THRESHOLD'" >&2
  exit 1
fi
XCRUN="${XCRUN:-xcrun}"

# Derive data path from build dir or explicit DERIVED_DATA
DERIVED_DATA="${DERIVED_DATA_DIR:-${BUILD_DIR:-build}/DerivedData}"

echo "--- Coverage check (default threshold: ${DEFAULT_THRESHOLD}%) ---"

# Locate the coverage profile
COV_FILE=""
for d in "${DERIVED_DATA}/Build/ProfileData" "${DERIVED_DATA}/Logs/Test"; do
  if [ -d "$d" ]; then
    COV_FILE=$(find "$d" -name '*.profdata' -maxdepth 1 -print -quit 2>/dev/null || true)
    [ -n "$COV_FILE" ] && break
  fi
done

if [ -z "$COV_FILE" ]; then
  echo "WARNING: No coverage profile data found in ${DERIVED_DATA}."
  echo "SKIPPED — no coverage data to check."
  echo ""
  echo "To generate coverage data, run tests with GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES"
  echo "and GCC_GENERATE_TEST_COVERAGE_FILES=YES, or enable 'Gather coverage data'"
  echo "in the Xcode test scheme."
  exit 0
fi

echo "Found coverage profile: $COV_FILE"

# Verify jq is available for JSON parsing
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found. Install via 'brew install jq'" >&2
  exit 1
fi

# --- Per-target threshold lookup ---
resolve_threshold() {
  local target="$1"
  local threshold_file="$PROJECT_DIR/scripts/coverage-thresholds.txt"
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

# --- Get coverage report ---
# xccov view --report --json outputs per-target coverage as a fraction (0-1)
REPORT_JSON=$($XCRUN xccov view --report --json "$COV_FILE" 2>/dev/null || true)

if [ -z "$REPORT_JSON" ]; then
  echo "WARNING: xccov report is empty — no test coverage data generated."
  echo "SKIPPED — no coverage data to check."
  exit 0
fi

FAILED=0
# Parse JSON with jq — extract name, lineCoverage (as integer percentage)
while IFS=$'\t' read -r TARGET PCT_INT; do
  # Skip test targets (suffixed with Test/Tests) and vendored frameworks
  case "$TARGET" in
    *Tests|*Test|AutoHyperlinks|MMTabBarView) continue ;;
  esac

  TARGET_THRESHOLD=$(resolve_threshold "$TARGET")

  if [ "$PCT_INT" -lt "$TARGET_THRESHOLD" ]; then
    echo "FAIL: $TARGET coverage ${PCT_INT}% < ${TARGET_THRESHOLD}%"
    FAILED=1
  else
    echo "OK:   $TARGET coverage ${PCT_INT}% >= ${TARGET_THRESHOLD}%"
  fi
done < <(echo "$REPORT_JSON" | jq -r '.targets[] | [.name, (.lineCoverage * 100 | floor)] | @tsv')

# --- Branch coverage report (non-gating, per §2.5) ---
# xccov view --report --json only gives line coverage. Branch coverage
# requires llvm-cov export over the profdata and a matching binary.
# Report it when available; gate on it only once line ≥90 across targets.
BINARY_DIR="${DERIVED_DATA}/Build/Products/Debug"
if [ -d "$BINARY_DIR" ]; then
  # Find a production binary to extract branch coverage from the profdata
  BINARY=$(find "$BINARY_DIR" -maxdepth 1 -type d -name '*.framework' -print -quit 2>/dev/null || true)
  if [ -n "$BINARY" ] && $XCRUN llvm-cov --help &>/dev/null; then
    BINARY_NAME=$(basename "$BINARY" .framework)
    BRANCH_REPORT=$($XCRUN llvm-cov export -summary-only \
      -instr-profile "$COV_FILE" "$BINARY/$BINARY_NAME" 2>/dev/null || true)
    if [ -n "$BRANCH_REPORT" ]; then
      BRANCH_PCT=$(echo "$BRANCH_REPORT" | jq -r '.data[0].totals.branches.percent // 0' 2>/dev/null || echo "N/A")
      echo "Branch coverage (${BINARY##*/}): ${BRANCH_PCT}%  (informational, not gated)"
    fi
  fi
else
  echo "Branch coverage: ${BINARY_DIR} not found — skipped"
fi

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAILED: Some targets below their coverage threshold. Raise thresholds"
  echo "in scripts/coverage-thresholds.txt or increase coverage."
  exit 1
fi

echo "All targets meet or exceed their coverage thresholds."
