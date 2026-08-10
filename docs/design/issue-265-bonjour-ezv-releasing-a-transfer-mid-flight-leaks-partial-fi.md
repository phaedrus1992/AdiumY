# Design: Bonjour EZV: releasing a transfer mid-flight leaks partial files and reports nothing

- **Issue:** [#265 — Bonjour EZV: releasing a transfer mid-flight leaks partial files and reports nothing](../../../../issues/265)
- **Status:** Proposed

## 1. Summary

## Summary

`EKEzvIncomingFileTransfer -dealloc` runs `[downloadSession invalidateAndCancel]` and only removes partial artifacts when `transferFailed && !transferSucceeded`. A transfer released while downloads are still in flight (neither failed nor succeeded) has `transferFailed == NO`, so:

1. `invalidateAndCancel` drops the in-flight tasks' `URLSession:task:didCompleteWithError:` callbacks — no success or failure is ever reported to the client.
2. The dealloc safety net does not run `removePartialTransferArtifacts` — any partial file(s) and created folder tree stay on disk.
3. No `transferFailed:` message reaches the client, so the UI is never told the transfer vanished.

## Repro

1. A folder transfer starts downloading (data tasks in flight, `transferFailed == NO`, `transferSucceeded == NO`).
2. The object owning the transfer releases it (e.g. the chat/conversation closes) before the tasks complete.
3. `dealloc` runs: session invalidated, callbacks dropped, partial artifacts left on disk, client never notified.

## Expected

A release mid-flight should either complete/fail the transfer through the normal cleanup paths or remove partial artifacts and report the cancellation, rather than leaking the partial state silently.

## Notes

- Deferred from sprint #262 during pre-PR review. Related to the #248 cleanup work; the guard added there (`if (transferFailed && !transferSucceeded)`) intentionally avoids removing a *successful* transfer's files but leaves the in-flight case uncovered.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

