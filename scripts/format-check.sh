#!/bin/bash
set -euo pipefail

# clang-format check — dry-run, fail on any differences
# Excludes: .framework bundles (binary), Dependencies/ (vendored),
#           AutoHyperlinks (forked), MMTabBarView (forked), .tmp/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Use project xcconfig for clang if available; fall back to PATH
CLANG_FORMAT="${CLANG_FORMAT:-clang-format}"

if ! command -v "$CLANG_FORMAT" &>/dev/null; then
  echo "ERROR: $CLANG_FORMAT not found. Install it via 'brew install clang-format'" >&2
  exit 1
fi

# Collect source files, excluding vendored/forked/third-party dirs
EXCLUDE_PATTERNS=(
  '-path' './Dependencies/*' '-prune'
  '-o' '-path' './Frameworks/AutoHyperlinks Framework/*' '-prune'
  '-o' '-path' './Frameworks/MMTabBarView.framework/*' '-prune'
  '-o' '-path' '*.framework/*' '-prune'
  '-o' '-path' './Plugins/Bonjour/libezv/*' '-prune'
  '-o' '-path' '*/JSONKit/*' '-prune'
  '-o' '-path' './Release/*' '-prune'
  '-o' '-path' './.tmp/*' '-prune'
  '-o' '-path' './build/*' '-prune'
  '-o' '-path' './.git/*' '-prune'
)

# --list: print null-terminated source file paths (for piping to xargs -0 clang-format -i)
if [ "${1:-}" = "--list" ]; then
  find . \( "${EXCLUDE_PATTERNS[@]}" \) -o \( \
    -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' \
  \) -print0 | sort -z
  exit 0
fi

echo "--- Running clang-format dry-run ---"

FILES=$(find . \( "${EXCLUDE_PATTERNS[@]}" \) -o \( \
  -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' \
\) -print | sort)

FILE_COUNT=$(echo "$FILES" | grep -c . || true)
echo "Found $FILE_COUNT source files"

# Run clang-format in dry-run mode — diff against original
FAILED=0
while IFS= read -r f; do
  if ! "$CLANG_FORMAT" --dry-run --Werror "$f"; then
    echo "FAIL: $f does not match style"
    FAILED=1
  fi
done <<< "$FILES"

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Some files don't match .clang-format style. Run 'make format' to fix."
  exit 1
fi

echo "All $FILE_COUNT files match style."
