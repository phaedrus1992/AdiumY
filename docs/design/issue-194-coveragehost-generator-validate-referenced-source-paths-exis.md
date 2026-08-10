# Design: CoverageHost generator: validate referenced source paths exist before emitting project

- **Issue:** [#194 — CoverageHost generator: validate referenced source paths exist before emitting project](../../../../issues/194)
- **Status:** Proposed

## 1. Summary

Found during sprint #189 (pre-pr-review code-reviewer on the CoverageHost harness).

**Where:** Tests/CoverageHost/generate-xcodeproj.py (757 lines).

**What:** The generator hardcodes source paths (libezv Classes/Other Sources/Private Classes dirs, WebKit Message View, etc.) into the emitted project but never checks that each referenced path exists before writing project.pbxproj. A stale or mistyped path (e.g. the space-containing HEADER_SEARCH_PATHS issue hit during #187) is only discovered when xcodebuild fails opaquely at build time, and the error message doesn't point at the generator.

**Why deferred:** pre-existing test-infrastructure hardening; the harness works, the gap is developer ergonomics and faster failure feedback, not a shipping bug.

**Suggested fix:** before writing, stat each file/path the project references and abort with a clear message naming the bad path; optionally fail if a declared source file has no matching file on disk.

Blocked by: nothing. Label: cleanup. Milestone: v2.0.0.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

