# Design: Add clang-format to pre-commit checks

- **Issue:** [#132 — Add clang-format to pre-commit checks](../../../../issues/132)
- **Status:** Proposed

## 1. Summary

**Context:** CI's `build` check runs `make format-check` (clang-format 22.1.8 dry-run) and fails when any tracked file drifts from `.clang-format`. Three PRs in a row have landed style violations that only CI caught (this PR: `Source/AICoreComponentLoader.m`, `AIMessageWindowController.m`, `adiumPurpleEventloop.m`).

**Request:** add a clang-format check to the pre-commit hooks (prek) so style violations are caught before commit instead of in CI. See `scripts/format-check.sh` and the `format-check`/`format` Makefile targets (they already pin `CLANG_FORMAT` resolution via brew).

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

