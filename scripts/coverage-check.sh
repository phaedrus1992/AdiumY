#!/bin/bash
set -euo pipefail

# Coverage threshold check for Xcode test runs
# Reads xccov report and fails if any production target is below THRESHOLD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

THRESHOLD="${COVERAGE_THRESHOLD:-50}"
# Validate threshold is numeric
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: COVERAGE_THRESHOLD must be a positive integer, got: '$THRESHOLD'" >&2
  exit 1
fi
XCRUN="${XCRUN:-xcrun}"

# Derive data path from build dir or explicit DERIVED_DATA
DERIVED_DATA="${DERIVED_DATA_DIR:-${BUILD_DIR:-build}/DerivedData}"

echo "--- Coverage check (threshold: ${THRESHOLD}%) ---"

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

# Get coverage report as JSON (more robust than text parsing — handles
# spaces in target names, locale-independent formatting)
# xccov view --report --json outputs per-target coverage as a fraction (0-1)
REPORT_JSON=$($XCRUN xccov view --report --json "$COV_FILE" 2>/dev/null || true)

if [ -z "$REPORT_JSON" ]; then
  echo "WARNING: xccov report is empty — no test coverage data generated."
  echo "SKIPPED — no coverage data to check."
  exit 0
fi

FAILED=0
# Parse JSON with jq — extract name and lineCoverage (as integer percentage)
while IFS=$'\t' read -r TARGET PCT_INT; do
  # Skip test targets (suffixed with Test/Tests) and frameworks we don't own
  case "$TARGET" in
    *Tests|*Test|AutoHyperlinks|MMTabBarView) continue ;;
  esac

  if [ "$PCT_INT" -lt "$THRESHOLD" ]; then
    echo "FAIL: $TARGET coverage ${PCT_INT}% < ${THRESHOLD}%"
    FAILED=1
  else
    echo "OK:   $TARGET coverage ${PCT_INT}% >= ${THRESHOLD}%"
  fi
done < <(echo "$REPORT_JSON" | jq -r '.targets[] | [.name, (.lineCoverage * 100 | floor)] | @tsv')

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "FAILED: Some targets below coverage threshold (${THRESHOLD}%)."
  exit 1
fi

echo "All targets meet or exceed ${THRESHOLD}% coverage."
