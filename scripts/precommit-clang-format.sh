#!/bin/bash
set -euo pipefail

# clang-format pre-commit hook — dry-run on staged source files.
#
# Invoked by prek (see .pre-commit-config.yaml) with the staged filenames that
# match the hook's `files` pattern. Mirrors scripts/format-check.sh: uses the
# same CLANG_FORMAT resolution and the same --dry-run --Werror semantics, so
# what fails here is exactly what CI's `make format-check` would fail.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

CLANG_FORMAT="${CLANG_FORMAT:-clang-format}"
if ! command -v "$CLANG_FORMAT" &>/dev/null; then
  echo "ERROR: $CLANG_FORMAT not found. Install it via 'brew install clang-format'" >&2
  exit 1
fi

FAILED=0
for f in "$@"; do
  if ! "$CLANG_FORMAT" --dry-run --Werror "$f" 2>/dev/null; then
    echo "FAIL: $f does not match .clang-format style" >&2
    FAILED=1
  fi
done

if [ "$FAILED" -eq 1 ]; then
  echo "Run 'make format' to fix, or 'git commit --no-verify' to bypass" >&2
  exit 1
fi
