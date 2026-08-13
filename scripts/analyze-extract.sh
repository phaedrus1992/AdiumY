#!/bin/bash
# Shared finding-extraction pipeline for the Clang Static Analyzer gate.
#
# Reads an `xcodebuild analyze` log on stdin and writes normalized
#   <checker>\t<path>\t<message>
# tuples to stdout, one per line, sorted and de-duplicated (sort -u). Line/column
# numbers are dropped so moving code doesn't churn the baseline.
#
# This is the single source of truth for extraction: scripts/analyze-check.sh
# (the gate) calls it, and Tests/CoverageHost/test_analyze_extract.py drives it
# directly with synthetic logs — the property-based tests must exercise the real
# pipeline, not a reimplementation (issue #346).
#
# Arguments:
#   $1  PROJECT_DIR — absolute repo root. Absolute paths under it are made
#       relative (stable baseline across checkouts); files outside the repo
#       (system headers) keep their absolute path. The string is escaped before
#       it goes into a sed PATTERN so a path like "my[repo]" can't corrupt the
#       prefix strip.
#
# Exit status:
#   0  extraction succeeded (output may be empty — nothing matched is the
#      normal incremental case)
#   1  extraction failed (unreadable input, sed/sort error) — fail closed, so
#      the caller never mistakes an empty output for "no findings"
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: analyze-extract.sh <PROJECT_DIR>" >&2
  exit 1
fi

PROJECT_DIR="$1"
ESCAPED_PROJECT_DIR="$(printf '%s' "$PROJECT_DIR" | sed -e 's/[][\\.^$|()*+?{}]/\\&/g')"

# Pattern rationale (both documented failure modes from issue #346):
#   * The checker suffix must be a DOTTED identifier (deadcode.DeadStores), not
#     any bracketed word — otherwise a message ending in prose like "[Note]" is
#     captured by the greedy bracket group as if it were the checker name, and
#     the emitted tuple never matches the baseline entry (false "new" finding).
#   * The path group is [^:]+ (POSIX ERE — no non-greedy quantifier on BSD sed,
#     the CI/macOS sed). A colon can never appear in a macOS filename, so the
#     FIRST colon in the line is always the ":line:col:" boundary: a message
#     that quotes "path:5:2: warning:"-style text cannot drag the boundary into
#     the path field (mis-split path).
EXTRACT_RC=0
grep -E 'warning: .* \[[A-Za-z][A-Za-z0-9._]*\.[A-Za-z][A-Za-z0-9._]*\]$' \
  | sed -E "s#^$ESCAPED_PROJECT_DIR/##" \
  | sed -E 's#^([^:]+):[0-9]+:[0-9]+: warning: (.*) \[([A-Za-z][A-Za-z0-9._]*\.[A-Za-z][A-Za-z0-9._]*)\]$#\3\t\1\t\2#' \
  | sort -u \
  || EXTRACT_RC=$?
if [ "$EXTRACT_RC" -ne 0 ] && [ "$EXTRACT_RC" -ne 1 ]; then
  echo "ERROR: finding extraction failed (rc $EXTRACT_RC)." >&2
  exit 1
fi
