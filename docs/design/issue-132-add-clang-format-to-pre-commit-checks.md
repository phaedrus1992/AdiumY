# Design: Add clang-format to pre-commit checks

- **Issue:** [#132 — Add clang-format to pre-commit checks](../../../../issues/132)
- **Status:** Implemented (sprint: composite #337 — CI quality gates)

## 1. Summary

**Context:** CI's `build` check runs `make format-check` (clang-format 22.1.8 dry-run) and fails when any tracked file drifts from `.clang-format`. Three PRs in a row have landed style violations that only CI caught (this PR: `Source/AICoreComponentLoader.m`, `AIMessageWindowController.m`, `adiumPurpleEventloop.m`).

**Request:** add a clang-format check to the pre-commit hooks (prek) so style violations are caught before commit instead of in CI. See `scripts/format-check.sh` and the `format-check`/`format` Makefile targets (they already pin `CLANG_FORMAT` resolution via brew).

## 2. Approach

The hook infra already exists: prek 0.3.2 is installed (`prek install` writes a
`.git/hooks/pre-commit` shim that execs prek), but no config file was present —
so the shim was a silent no-op. This change adds the config and the hook it runs.

1. **`.pre-commit-config.yaml`** (new, root) — prek's pre-commit-compatible config
   format (prek also accepts a native `prek.toml`; `.pre-commit-config.yaml` is
   chosen so plain `pre-commit` works interchangeably). One `local` repo hook,
   `clang-format`, `language: system`, restricted by `files: \.(m|mm|h|c|cc|cpp)$`,
   `pass_filenames: true` (prek passes staged, matching filenames to the entry).
2. **`scripts/precommit-clang-format.sh`** (new) — the hook entry. Loops over the
   staged filenames prek passes and runs `clang-format --dry-run --Werror` on each,
   resolving `CLANG_FORMAT` exactly like `scripts/format-check.sh` (so the same
   brew-pinned clang-format used by CI). Fails with a `make format` hint. Intent:
   the pre-commit gate is byte-for-byte the same style check CI runs.
3. **`Makefile` `install-hooks`** (replaced) — the old target wrote an inline bash
   hook directly to `.git/hooks/pre-commit`; it is replaced by `prek install`
   (idempotent, keeps the shim in sync with the config). Not "redundant hooks".

Why `language: system` + a local script instead of the pre-commit
`pre-commit/mirrors-clang-format` remote hook: the mirrors hook pins a specific
clang-format release and re-downloads it, while the repo already pins resolution
via brew and CI (`CLANG_FORMAT`). One mechanism for local and CI = no version drift.

Scope: staged-file dry-run only. `make format` still applies fixes; `make
format-check` still gates CI over *all* tracked files. The hook does not auto-fix
(least surprise for a commit gate).

## 3. Verification

- [x] `prek validate-config .pre-commit-config.yaml` → success
- [x] `prek list` → `.:clang-format`
- [x] `prek run clang-format --files <conforming>` → Passed
- [x] `prek run clang-format --files <non-conforming>` → Failed (exit 1, `make format` hint)
- [x] CI `make format-check` still passes on the changed tree (format-check.sh untouched)

