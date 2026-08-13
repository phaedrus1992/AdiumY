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

# Per-run scratch for tool stderr captured instead of discarded — a failing
# xccov/llvm-cov must surface its own reason, not abort silently (or misread
# a broken report as an empty one).
SCRATCH_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

DEFAULT_THRESHOLD="${COVERAGE_THRESHOLD:-50}"
if ! [[ "$DEFAULT_THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "ERROR: COVERAGE_THRESHOLD must be a positive integer, got: '$DEFAULT_THRESHOLD'" >&2
  exit 1
fi
XCRUN="${XCRUN:-xcrun}"

# Derive data path from build dir or explicit DERIVED_DATA
DERIVED_DATA="${DERIVED_DATA_DIR:-${BUILD_DIR:-build}/DerivedData}"

echo "--- Coverage check (default threshold: ${DEFAULT_THRESHOLD}%) ---"

# Locate the coverage profile. find errors (e.g. an unreadable directory) are
# captured to scratch and surfaced — a gate that can't find its data must say
# why, not swallow the error (previously `2>/dev/null || true` hid the cause).
COV_FILE=""
COV_ERR="$SCRATCH_DIR/find-profdata.err"
for d in "${DERIVED_DATA}/Build/ProfileData" "${DERIVED_DATA}/Logs/Test"; do
  if [ -d "$d" ]; then
    find_rc=0
    COV_FILE=$(find "$d" -name '*.profdata' -maxdepth 4 -print -quit 2>"$COV_ERR") || find_rc=$?
    if [ -s "$COV_ERR" ]; then
      echo "WARNING: error locating coverage profile under $d:" >&2
      sed 's/^/  /' "$COV_ERR" >&2
    fi
    if [ "$find_rc" -ne 0 ]; then
      echo "ERROR: find failed (rc $find_rc) locating coverage profile — cannot verify coverage." >&2
      exit 1
    fi
    [ -n "$COV_FILE" ] && break
  fi
done

if [ -z "$COV_FILE" ]; then
  if [ "${ALLOW_NO_COVERAGE:-0}" = "1" ]; then
    echo "WARNING: No coverage profile data found in ${DERIVED_DATA}."
    echo "SKIPPED (ALLOW_NO_COVERAGE=1) — no coverage data to check."
    exit 0
  fi
  echo "ERROR: No coverage profile data found in ${DERIVED_DATA}."
  echo "The coverage gate must not pass unmeasured. Generate coverage data by running"
  echo "tests with -enableCodeCoverage YES and targets with CLANG_COVERAGE_MAPPING=YES"
  echo "CLANG_PROFILE_INSTRUMENTATION=YES, or set ALLOW_NO_COVERAGE=1 to explicitly skip."
  exit 1
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
# xccov view --report --json outputs per-target coverage as a fraction (0-1).
# A non-zero exit is NOT an error here: when coverage comes from pre-built,
# CLANG_PROFILE_INSTRUMENTATION frameworks, the merged profdata is llvm-cov
# format and xccov rejects it with "unrecognized file format" — that is the
# designed handoff to the llvm-cov section below. What matters is that xccov's
# stderr is surfaced rather than discarded, and that an empty report degrades
# to INFO (the llvm-cov section measures it), not to a silent pass.
XCC_ERR="$SCRATCH_DIR/xccov.err"
REPORT_JSON=$("$XCRUN" xccov view --report --json "$COV_FILE" 2>"$XCC_ERR" || true)

if [ -z "$REPORT_JSON" ]; then
  echo "INFO: xccov report is empty — no test-run targets in profdata. Pre-built framework check follows."
  if [ -s "$XCC_ERR" ]; then
    echo "  xccov: $(cat "$XCC_ERR")" >&2
  fi
fi

FAILED=0

# Parse JSON with jq — extract name and lineCoverage (as integer percentage)
# Only parse if xccov actually returned data
if [ -n "$REPORT_JSON" ]; then
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
fi

# ---- llvm-cov check for pre-built frameworks ----
# xccov only reports targets compiled during `xcodebuild test`. Frameworks
# built separately with CLANG_COVERAGE_MAPPING/CLANG_PROFILE_INSTRUMENTATION
# must be checked via llvm-cov against their binary and the merged profdata.
BUILD_PRODUCTS="${DERIVED_DATA}/Build/Products/Debug"
if [ -d "$BUILD_PRODUCTS" ]; then
  echo ""
  echo "--- Pre-built framework coverage (llvm-cov) ---"
  for fw_dir in "$BUILD_PRODUCTS"/*.framework; do
    [ -d "$fw_dir" ] || continue
    fw_name="$(basename "$fw_dir" .framework)"
    # Skip vendored frameworks
    case "$fw_name" in
      AutoHyperlinks|MMTabBarView) continue ;;
    esac
    fw_binary="$fw_dir/Versions/A/$fw_name"
    [ -f "$fw_binary" ] || fw_binary="$fw_dir/$fw_name"
    [ -f "$fw_binary" ] || continue

    # Pass native arch for universal (fat) binaries — llvm-cov needs it
    native_arch=$(uname -m)

    # `|| true`: a failing llvm-cov must not set -e abort the whole check with
    # no diagnostic. Capture its stderr so the reason degrades to the WARN path
    # below instead of being discarded (previously 2>/dev/null hid the cause).
    llvm_cov_err="$SCRATCH_DIR/llvm-cov-$fw_name.err"
    llvm_cov_rc=0
    cov_pct=$("$XCRUN" llvm-cov report -arch "$native_arch" \
      --instr-profile="$COV_FILE" --object="$fw_binary" 2>"$llvm_cov_err" \
      | awk '$1 == "TOTAL" {gsub(/%/, "", $10); print $10}') || llvm_cov_rc=$?

    # A TOTAL row followed by a crash means llvm-cov died partway — the
    # percentage is untrustworthy. Distinguish this from a genuinely
    # uninstrumented binary, which llvm-cov reports as rc 1 with empty stdout
    # ("no coverage data found"): that stays a WARN, not a false ERROR.
    if [ -n "$cov_pct" ] && [ "$llvm_cov_rc" -ne 0 ]; then
      echo "ERROR: llvm-cov produced partial output then failed for $fw_name — coverage not measured:" >&2
      if [ -s "$llvm_cov_err" ]; then
        sed 's/^/  /' "$llvm_cov_err" >&2
      fi
      FAILED=1
      continue
    fi

    if [ -z "$cov_pct" ] || [ "$cov_pct" = "-" ] || [ "$cov_pct" = "0.00" ]; then
      echo "WARN: $fw_name — no coverage data (not instrumented or not exercised)"
      if [ -s "$llvm_cov_err" ]; then
        echo "  llvm-cov: $(cat "$llvm_cov_err")" >&2
      fi
      continue
    fi

    pct_int=$(printf "%.0f" "$cov_pct" 2>/dev/null || echo 0)
    TARGET_THRESHOLD=$(resolve_threshold "$fw_name")

    if [ "$pct_int" -lt "$TARGET_THRESHOLD" ]; then
      echo "FAIL: $fw_name line coverage ${cov_pct}% < ${TARGET_THRESHOLD}%"
      FAILED=1
    else
      echo "OK:   $fw_name line coverage ${cov_pct}% >= ${TARGET_THRESHOLD}%"
    fi
  done
fi

# --- Branch coverage report (non-gating, per §2.5) ---
# xccov view --report --json only gives line coverage. Branch coverage
# requires llvm-cov export over the profdata and a matching binary.
# Report it when available; gate on it only once line ≥90 across targets.
BINARY_DIR="${DERIVED_DATA}/Build/Products/Debug"
if [ -d "$BINARY_DIR" ]; then
  # Find a production binary to extract branch coverage from the profdata
  BINARY=$(find "$BINARY_DIR" -maxdepth 1 -type d -name '*.framework' -print -quit 2>/dev/null || true)
  if [ -n "$BINARY" ] && "$XCRUN" llvm-cov --help &>/dev/null; then
    BINARY_NAME=$(basename "$BINARY" .framework)
    BRANCH_ERR="$SCRATCH_DIR/branchcov.err"
    # Pass the native arch for universal (fat) binaries, same as the per-target
    # llvm-cov report above — llvm-cov export refuses a fat binary without it
    # ("-arch specifier is invalid or missing for universal binary").
    BRANCH_REPORT=$("$XCRUN" llvm-cov export -summary-only -arch "$(uname -m)" \
      -instr-profile "$COV_FILE" "$BINARY/$BINARY_NAME" 2>"$BRANCH_ERR" || true)
    if [ -n "$BRANCH_REPORT" ]; then
      BRANCH_PCT=$(echo "$BRANCH_REPORT" | jq -r '.data[0].totals.branches.percent // 0' 2>/dev/null || echo "N/A")
      echo "Branch coverage (${BINARY##*/}): ${BRANCH_PCT}%  (informational, not gated)"
    elif [ -s "$BRANCH_ERR" ]; then
      echo "Branch coverage: llvm-cov export failed — ${BINARY##*/}" >&2
      sed 's/^/  /' "$BRANCH_ERR" >&2
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

echo ""
echo "All targets meet or exceed their coverage thresholds."
