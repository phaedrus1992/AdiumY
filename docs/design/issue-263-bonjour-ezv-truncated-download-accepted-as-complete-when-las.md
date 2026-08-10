# Design: Bonjour EZV: truncated download accepted as complete when last task ends without error

- **Issue:** [#263 — Bonjour EZV: truncated download accepted as complete when last task ends without error](../../../../issues/263)
- **Status:** Proposed

## 1. Summary

## Summary

A Bonjour EZV incoming transfer is marked `transferSucceeded` as soon as its last data task completes without error — `EKEzvIncomingFileTransfer.m` `URLSession:task:didCompleteWithError:` keys the success gate on `[currentDownloads count] == 0` and `error == nil` (the #260 fix). It never cross-checks `bytesReceived` against the peer-declared `size`. `bytesReceived` feeds only the progress percent.

## Repro

1. A LAN peer advertises an incoming transfer whose declared `<size>` is larger than the bytes it actually sends (or the transfer metadata declares a size the peer never delivers).
2. The single data task completes without an error.
3. `[currentDownloads count] == 0` → `applyPermissions` runs, `transferSucceeded = YES`, the truncated file is kept on disk and its permissions are applied.

## Expected

A transfer whose received byte count does not match the declared size should be treated as failed (report the mismatch, remove the partial artifact) rather than silently accepted as complete.

## Notes

- Same root cause family as #260 (peer-supplied `size` is untrusted) but the opposite symptom: #260 was "never completes", this is "completes even when truncated".
- Practical exposure is narrow — NSURLSession reports connection cuts as errors — but the peer-declared `<size>` attribute is never validated against the body length for any transfer.
- Deferred from sprint #262 during pre-PR review; needs a decision on whether to cross-check bytes vs declared size and the failure behavior on mismatch.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

