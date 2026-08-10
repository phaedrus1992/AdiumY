# Design: Bonjour EZV: folder walk silently skips a file when its built URL is invalid

- **Issue:** [#264 — Bonjour EZV: folder walk silently skips a file when its built URL is invalid](../../../../issues/264)
- **Status:** Proposed

## 1. Summary

## Summary

In `EKEzvIncomingFileTransfer -downloadFolder:path:url:depth:` the child file URL is built with `[rootURL stringByAppendingPathComponent:percentEncodedName]`, then stored as `[NSURL URLWithString:newURL]`. When `newURL` is not a valid absolute URL, `URLWithString:` returns nil, and the KVC `[itemsToDownload setValue:nil forKey:newPath]` silently removes the entry (`setValue:forKey:` with nil removes, it does not raise). The file is dropped from the folder transfer with no error reported and no transfer failure.

## Repro

1. A directory transfer whose base URL (or a percent-encoded child name) does not form a parseable absolute URL — e.g. the peer-supplied base `<url>` is malformed, or a name encodes in a way that corrupts the combined URL.
2. The walk reports success for the child (returns YES at `downloadFolder:`), but no download task is created for it.
3. The folder transfer completes with the file silently missing.

## Expected

A child that cannot be resolved to a download URL should fail the transfer (or at minimum report an error), matching how invalid names and depth-cap cases are handled (issues #181, #187, #191) — never a silent skip.

## Notes

- Deferred from sprint #262 during pre-PR review. The `safeName` length check and depth cap already fail loudly; the URL-build result is the one path that skips silently.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

