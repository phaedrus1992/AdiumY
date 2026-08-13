#!/bin/bash
set -euo pipefail

# Clang Static Analyzer gate for AIUtilities.framework.
# Runs `xcodebuild analyze` and fails if the analyzer reports any findings.
# Analyzer findings carry a [checker.name] suffix (e.g. [unix.Malloc]);
# ordinary compiler warnings carry [-Wflag] and are deliberately not a gate
# failure.
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

# On a clean checkout (CI runner, no prior build) build/ doesn't exist yet.
# tee can't open the log without it — create it first, or the gate dies with a
# misleading tee error before the analyzer even runs.
mkdir -p "$(dirname "$LOG_FILE")"

echo "--- Running Clang Static Analyzer (AIUtilities.framework) ---"

# pipefail: a failed analyze must fail the gate, and `tee` still writes the
# full log so the CI upload-artifact / debugging path has it.
xcodebuild -project Frameworks/AIUtilities/AIUtilities.xcodeproj \
           -target AIUtilities.framework \
           -configuration Debug \
           -sdk macosx \
           SYMROOT="$PWD/build/analyze/Build/Products" \
           OBJROOT="$PWD/build/analyze/Build/Intermediates" \
           CODE_SIGNING_ALLOWED=NO \
           CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED=NO \
           analyze 2>&1 | tee "$LOG_FILE"

# The log must exist for the gate to mean anything — grep rc=2 (missing file)
# must fail loudly, not read as "no findings".
if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: $LOG_FILE not found — analyze produced no log." >&2
  exit 1
fi

# Anchor the checker name at EOL: analyzer findings end in [checker.name];
# compiler warnings end in [-Wflag] and must not trip the gate.
if grep -nE 'warning:.*\[[A-Za-z][A-Za-z0-9._]*\]$' "$LOG_FILE"; then
  echo ""
  echo "FAILED: Clang Static Analyzer found findings in AIUtilities.framework."
  echo "Fix them (or file a follow-up issue) before merging."
  exit 1
fi

echo ""
echo "Analyze clean: no Clang Static Analyzer findings."
