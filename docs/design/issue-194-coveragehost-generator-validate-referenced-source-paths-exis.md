# Design: CoverageHost generator: validate referenced source paths exist before emitting project

- **Issue:** [#194 — CoverageHost generator: validate referenced source paths exist before emitting project](../../../../issues/194)
- **Status:** Implemented

## 1. Summary

Found during sprint #189 (pre-pr-review code-reviewer on the CoverageHost harness).

**Where:** Tests/CoverageHost/generate-xcodeproj.py (757 lines).

**What:** The generator hardcodes source paths (libezv Classes/Other Sources/Private Classes dirs, WebKit Message View, etc.) into the emitted project but never checks that each referenced path exists before writing project.pbxproj. A stale or mistyped path (e.g. the space-containing HEADER_SEARCH_PATHS issue hit during #187) is only discovered when xcodebuild fails opaquely at build time, and the error message doesn't point at the generator.

**Why deferred:** pre-existing test-infrastructure hardening; the harness works, the gap is developer ergonomics and faster failure feedback, not a shipping bug.

**Suggested fix:** before writing, stat each file/path the project references and abort with a clear message naming the bad path; optionally fail if a declared source file has no matching file on disk.

Blocked by: nothing. Label: cleanup. Milestone: v2.0.0.

## 2. Approach

Implemented in sprint #297 (PR #299) via `validate_source_paths` in
`Tests/CoverageHost/generate_xcodeproj_core.py`, wired into
`generate-xcodeproj.py` after the project model is built:

- Every `PBXFileReference` whose `lastKnownFileType` is `sourcecode.*` (ObjC/C/
  C++ sources + headers) or `text.plist.*` (Info.plist) is stat'd relative to
  the project dir.
- Framework refs (`wrapper.*`) are excluded — they're linked, not compiled, and
  system frameworks (`sourceTree: <absolute>`, e.g. XCTest) legitimately live
  outside the repo.
- Refs with a non-`<group>` `sourceTree` (`BUILT_PRODUCTS_DIR`, `SOURCE_ROOT`)
  are skipped, mirroring the source resolver, so a product ref can't hard-abort
  regeneration with a misleading "missing source" error.
- Refs carrying an unresolvable `$(...)` build variable are skipped with a
  WARNING.
- On any genuinely missing path the generator aborts with a `SystemExit` naming
  each missing file, instead of letting xcodebuild fail opaquely at build time.

The check lives in the pure, unit-tested core module and is covered by the
stdlib-only `unittest` suite run in CI (the extraction that made it testable is
issue #294).

## 3. Verification

- [x] Verify fix/feature works as described

