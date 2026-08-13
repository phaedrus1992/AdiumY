#!/bin/bash
set -euo pipefail
# Deterministic collation: comm's sortedness check uses C ordering, but sort -u
# defaults to the user locale — the two disagree on paths like "SLPurple" vs
# "libpurple_extensions" (C: uppercase < lowercase; UTF-8 folds case), making
# comm emit spurious "not in sorted order" warnings and, worse, potentially
# misorder the comparison. Pin both to byte order.
export LC_ALL=C

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

# The log must exist for the gate to mean anything — grep rc=2 (missing file)
# must fail loudly, not read as "no findings".
if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: $LOG_FILE not found — analyze produced no log." >&2
  exit 1
fi

# Extract findings, normalized to checker\trelative-path\tmessage. Paths are
# made relative to the repo root so the baseline is identical on any checkout
# location; line/column numbers are dropped so moving code doesn't churn it.
# Pure sed pipeline (no read loop): the analyzer always emits absolute paths
# under $PROJECT_DIR, so strip that prefix first, then reshape. Files outside
# the repo (system headers) keep their absolute path — still a stable key.
# grep exits 1 when nothing matches — which is the normal incremental case
# (xcodebuild analyze re-analyses nothing when the derived data is already
# current, emitting zero warnings). pipefail + set -e would turn that into a
# gate failure, so tolerate the empty extraction; an empty findings file means
# "nothing new", which is exactly what comm below needs to pass.
grep -E 'warning: .* \[[A-Za-z][A-Za-z0-9._]*\]$' "$LOG_FILE" \
  | sed -E "s#^$PROJECT_DIR/##" \
  | sed -E 's#^(.+):[0-9]+:[0-9]+: warning: (.*) \[([A-Za-z][A-Za-z0-9._]*)\]$#\3\t\1\t\2#' \
  | sort -u > "$FINDINGS_FILE" \
  || true

# Findings not in the baseline are NEW — fail the gate on them. The baseline
# may carry '#'-prefixed rationale comments; strip them before comparing, and
# treat a missing baseline as empty (first run: every finding is new).
if [ -f "$BASELINE_FILE" ]; then
	BASELINE_SORTED="$(grep -v '^#' "$BASELINE_FILE" | sort -u)"
else
	BASELINE_SORTED=""
fi
NEW_FINDINGS="$(comm -23 "$FINDINGS_FILE" <(printf '%s\n' "$BASELINE_SORTED"))"

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
  STALE_BASELINE="$(comm -13 "$FINDINGS_FILE" <(printf '%s\n' "$BASELINE_SORTED"))"
  if [ -n "$STALE_BASELINE" ]; then
    echo "Note: baseline entries in scripts/analyze-baseline.txt no longer match any"
    echo "finding (the underlying issue may be fixed) — consider removing:"
    echo "  ${STALE_BASELINE//$'\n'/$'\n  '}"
  fi
fi

echo ""
echo "Analyze clean: no new Clang Static Analyzer findings."
