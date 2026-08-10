# Design: Harden register-side enum-indexed C-array writes against out-of-range values

- **Issue:** [#245 — Harden register-side enum-indexed C-array writes against out-of-range values](../../../../issues/245)
- **Status:** Proposed

## 1. Summary

## Summary

Register-side enum-indexed C-arrays lack bounds checks. An out-of-range value writes out of bounds through a caller-controlled enum index.

Found during sprint #244 (plugin uninstall teardown) pre-pr-review, `variant-bug-hunter`. Pre-existing — the sprint's new `unregisterStatusesForService:` iterates the same array safely (0..STATUS_TYPES_COUNT-1); the register side was never guarded.

## Sites

- `Source/AIStatusController.m:219` — `registerStatus:withDescription:ofType:forService:` indexes `statusDictsByServiceCodeUniqueID[type]` (a 4-slot C array, STATUS_TYPES_COUNT=4) with the caller-supplied `type` and no bounds validation. An out-of-range `AIStatusType` is an OOB write.
- `Source/ESContactAlertsController.m:86` — `globalOnlyEventHandlersByGroup[inGroup]` indexed with no bounds check.
- `Source/ESContactAlertsController.m:93` — `eventHandlersByGroup[inGroup]` indexed with no bounds check.

`registerEventID:inGroup:` is callable by plugins with a group argument; there is no runtime validation anywhere in the chain.

## Suggested fix

`NSParameterAssert` before indexing, modeled on the existing guard in `AdiumContentFiltering.m:49-50` (`NSParameterAssert(type >= 0 && type < FILTER_TYPE_COUNT)`):

- `NSParameterAssert(type >= AIAvailableStatusType && type < STATUS_TYPES_COUNT);` in `registerStatus:withDescription:ofType:forService:`
- `NSParameterAssert(inGroup >= 0 && inGroup < EVENT_HANDLER_GROUP_COUNT);` at both `ESContactAlertsController.m` sites

For symmetry, the new `unregisterStatusesForService:` should get the same assert.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

