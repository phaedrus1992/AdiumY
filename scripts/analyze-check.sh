#!/bin/bash
set -euo pipefail

# Clang Static Analyzer gate for the full AdiumY app.
# Runs `xcodebuild analyze` against the `AdiumY - Debug` scheme (AdiumY.app plus
# its dependencies: AdiumY.Framework, AdiumYLibpurple, AIUtilities, etc.) and
# fails if the analyzer reports any finding not already triaged.
# Analyzer findings carry a [checker.name] suffix (e.g. [unix.Malloc]);
# ordinary compiler warnings carry [-Wflag] and are deliberately not a gate
# failure.
#
# Pre-existing, triaged findings live in scripts/analyze-baseline.txt, one per
# line, tab-separated: <checker>\t<relative-path>\t<message>. Each entry is
# either a documented false positive or a genuinely-deferred bug with a
# rationale comment. The gate fails on findings NOT in the baseline, so it
# starts green and only blocks new findings.
#
# Mirrors the `analyze` CI job in .github/workflows/ci.yml so the gate behaves
# identically locally and on the runner. Run via `make analyze`.
#
# CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED=NO disables the opt-in
# NonLocalizedStringChecker (enabled in the pbxproj) — localization linting is
# out of scope for this gate.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

LOG_FILE="$PROJECT_DIR/build/analyze.log"
FINDINGS_FILE="$PROJECT_DIR/build/analyze-findings.txt"
BASELINE_FILE="$PROJECT_DIR/scripts/analyze-baseline.txt"

# On a clean checkout (CI runner, no prior build) build/ doesn't exist yet.
# tee can't open the log without it — create it first, or the gate dies with a
# misleading tee error before the analyzer even runs.
mkdir -p "$(dirname "$LOG_FILE")"

echo "--- Running Clang Static Analyzer (AdiumY - Debug scheme) ---"

# Run without -e so a failed analyze (compile error, codesign problem) is
# surfaced as the gate's own failure, not an opaque set -e abort. pipefail
# keeps xcodebuild's real exit status through the tee.
set +e
xcodebuild -project Adium.xcodeproj \
           -scheme "AdiumY - Debug" \
           -configuration Debug \
           -sdk macosx \
           SYMROOT="$PWD/build/analyze/Build/Products" \
           OBJROOT="$PWD/build/analyze/Build/Intermediates" \
           CODE_SIGNING_ALLOWED=NO \
           CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED=NO \
           analyze 2>&1 | tee "$LOG_FILE"
XCODE_RC=${PIPESTATUS[0]}
set -e

if [ "$XCODE_RC" -ne 0 ]; then
  echo "ERROR: xcodebuild analyze failed (rc $XCODE_RC) — see $LOG_FILE." >&2
  exit 1
fi

# The log must exist AND show the analyzer ran to completion for the gate to
# mean anything — a missing log must fail loudly, not read as "no findings".
# xcodebuild prints `** ANALYZE SUCCEEDED **` when the analyze action finishes
# (verified on both full and incremental runs); its absence with rc=0 means the
# action was skipped or the log is stale, and extracting "no findings" from a
# log with no analysis in it would be a false pass.
if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: $LOG_FILE not found — analyze produced no log." >&2
  exit 1
fi
if ! grep -q '\*\* ANALYZE SUCCEEDED \*\*' "$LOG_FILE"; then
  echo "ERROR: $LOG_FILE lacks the '** ANALYZE SUCCEEDED **' marker — analyze did not complete." >&2
  exit 1
fi

# Extract findings, normalized to checker\trelative-path\tmessage — delegated to
# the shared pipeline scripts/analyze-extract.sh, the single source of truth
# exercised directly by Tests/CoverageHost/test_analyze_extract.py (issue #346).
# It reads the log on stdin, strips the repo-root prefix (leaving system-header
# paths absolute — still a stable key), drops line/column, and fails closed
# (exit 1) on any extraction error: only "nothing matched" (grep rc=1, the
# normal incremental case) is tolerated, so a non-zero rc here is a real error,
# never a silent empty-findings pass. The `** ANALYZE SUCCEEDED **` check above
# already proved analysis ran, so an extraction failure is not a no-op.
if ! "$SCRIPT_DIR/analyze-extract.sh" "$PROJECT_DIR" < "$LOG_FILE" > "$FINDINGS_FILE"; then
  echo "ERROR: finding extraction failed — see $LOG_FILE." >&2
  exit 1
fi

# Findings not in the baseline are NEW — fail the gate on them. The baseline
# may carry '#'-prefixed rationale comments; strip them before comparing, and
# treat a missing or unreadable baseline as empty (first run: every finding is
# new). That last case is fail-closed by design: an empty baseline makes every
# finding read as "new" and the gate fails — never a silent pass. -F -x makes
# the compare an exact whole-line set difference, so no sort/collation pinning
# is needed (a missing baseline degrades to an empty pattern set, same result).
BASELINE_ACTIVE="$(grep -v '^#' "$BASELINE_FILE" 2>/dev/null || true)"
NEW_FINDINGS="$(grep -vxF -f <(printf '%s\n' "$BASELINE_ACTIVE") "$FINDINGS_FILE" || true)"

if [ -n "$NEW_FINDINGS" ]; then
  echo ""
  echo "FAILED: Clang Static Analyzer found findings not in scripts/analyze-baseline.txt:"
  echo "$NEW_FINDINGS" | while IFS=$'\t' read -r checker file msg; do
    printf '  %s  %s\n      checker: %s\n' "$file" "$msg" "$checker"
  done
  echo ""
  echo "Fix them (or add to the baseline with a rationale) before merging."
  exit 1
fi

# Hygiene check: baseline entries that no longer match any finding are stale —
# the gate is over-permissive while they linger. Warn, don't fail. Skip when
# the findings file is empty (incremental run, nothing re-analyzed): an empty
# set makes every baseline entry look stale, which is noise, not signal.
if [ -s "$FINDINGS_FILE" ]; then
  STALE_BASELINE="$(printf '%s\n' "$BASELINE_ACTIVE" | grep -vxF -f "$FINDINGS_FILE" || true)"
  if [ -n "$STALE_BASELINE" ]; then
    echo "Note: baseline entries in scripts/analyze-baseline.txt no longer match any"
    echo "finding (the underlying issue may be fixed) — consider removing:"
    echo "  ${STALE_BASELINE//$'\n'/$'\n  '}"
  fi
fi

echo ""
echo "Analyze clean: no new Clang Static Analyzer findings."
