# Design: Remove SUStatusChecker usage from the crash reporter

- **Issue:** [#68 — AICrashReporter uses SUStatusChecker (removed in Sparkle 2.x)](../../../../issues/68)
- **Status:** Proposed
- **Scope:** `Other/Adium Crash Reporter/AICrashReporter.h`, `Other/Adium Crash Reporter/AICrashReporter.m`

## 1. Problem

The crash reporter references `SUStatusChecker`, a Sparkle 1.x class that no longer
exists in the vendored Sparkle 2.9.4:

- `AICrashReporter.h:23-24` — `@class SUStatusChecker`, `@protocol SUStatusCheckerDelegate`
- `AICrashReporter.h:26` — conforms to `<SUStatusCheckerDelegate>`
- `AICrashReporter.h:48` — ivar `SUStatusChecker *statusChecker`
- `AICrashReporter.m:65` — `[statusChecker release]`
- `AICrashReporter.m:449-475` — `performVersionChecking` /
  `statusChecker:foundVersion:isNewVersion:` / `versionCheckingTimedOut`

`AICrashReporter` is not a member of any Xcode target (`rg AICrashReporter
Adium.xcodeproj/project.pbxproj` → no matches), so the main build is unaffected —
this is dead code that cannot compile if ever re-added.

## 2. What the code was for

`performVersionChecking` asked Sparkle's status checker whether a newer Adium
exists, then `finishWithAcceptableVersion:` gated crash submission: reports were
only sent from up-to-date builds. On any failure/timeout it allowed the report
anyway. Submission itself posts to
`https://github.com/phaedrus1992/adiumy/crash/post.jsp` (`AICrashReporter.m:25`) — dead
third-party infrastructure. The fork has no crash-report endpoint, so the version
gate protects a submission pipeline that no longer exists.

## 3. Design

**Remove the version check, keep the file compiling-clean for the future.** Do not
port to `SPUUpdater checkForUpdateInformation` — that adds live Sparkle plumbing to
a tool whose only consumer (the crash endpoint) is dead. If the fork ever gets
crash reporting, it will be rebuilt around a modern service, not this class.

### Steps

1. In `AICrashReporter.h`:
   - Remove `SUStatusChecker` from the `@class` line (line 23) and delete the
     `@protocol SUStatusCheckerDelegate;` forward declaration (line 24).
   - Remove `<SUStatusCheckerDelegate>` conformance (line 26).
   - Delete the `statusChecker` ivar (line 48).
2. In `AICrashReporter.m`:
   - Delete `[statusChecker release];` (line 65).
   - Delete `performVersionChecking`, `versionCheckingTimedOut`, and
     `statusChecker:foundVersion:isNewVersion:` (lines ~447-475).
   - Find the caller of `performVersionChecking` (it drives the submission flow)
     and replace the call with a direct
     `[self finishWithAcceptableVersion:YES newVersionString:nil];` so the
     control flow is unchanged minus the network probe.
   - Remove any now-unused Sparkle `#import`.
3. Do not add the file to any target. Do not touch `CRASH_REPORT_URL` or other
   constants — out of scope here (the reporter's overall fate is a separate
   decision).

## 4. Verification

- `rg -n "SUStatusChecker|statusChecker" "Other/Adium Crash Reporter"` returns
  nothing.
- Syntax check the standalone file compiles (it's targetless, so do a one-off):

  ```
  xcrun clang -fsyntax-only -x objective-c \
      -F Frameworks "Other/Adium Crash Reporter/AICrashReporter.m" -I <headers as needed>
  ```

  (No `-fobjc-arc` — the file uses manual retain/release.)

  If the file's pre-existing includes make a standalone syntax check impractical,
  a careful review that no removed symbol is still referenced is acceptable —
  the file was not compiling before this change either.

## 5. Alternative considered

Migrate to `SPUUpdater`'s `-checkForUpdateInformation` with an
`SPUUpdaterDelegate` implementing `updater:didFindValidUpdate:` /
`updaterDidNotFindUpdate:`. Rejected: real API surface (needs an
`SPUStandardUserDriver` or headless driver, delegate wiring, timeout handling) to
preserve a gate on a dead submission URL. If the reporter is ever revived (see the
note in the issue), that revival should decide whether a version gate is even
wanted.
