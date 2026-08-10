# Design: XtrasCreator: build fails against modern macOS SDK (Carbon APIs removed)

- **Issue:** [#163 — XtrasCreator: build fails against modern macOS SDK (Carbon APIs removed)](../../../../issues/163)
- **Status:** Proposed

## 1. Summary

## Summary

`Other/XtrasCreator` fails to build against the modern macOS SDK (22 errors), because several legacy source files depend on Carbon APIs that Apple removed from the SDK. The bundle-ID cleanup in the AdiumY fork is unaffected — this is a pre-existing incompatibility, surfaced while building XtrasCreator during the #161 sprint. Deferred out of scope; tracking it here so it's not silently lost.

## Errors

All 22 errors come from three files that were **not** touched by the fork's rename work:

- `Other/XtrasCreator/IconFamily.m` — `FSpCreateResFile`, `ReadIconFile`, `GetIconRefFromFile`, `CGDirectPaletteRef`, plus heavy use of `Handle`/`FSSpec`/`FSRef`/`ResFileRefNum` resource-manager APIs (`AddResource`, `GetResource`, `CloseResFile`)
- `Other/XtrasCreator/NSString+CarbonFSSpecCreation.m` — Carbon `FSRef`/`FSSpec` creation helpers
- `Other/XtrasCreator/NSMutableArrayAdditions.m` — Carbon-related additions

The three files this fork's cleanup did touch (`AXCAbstractXtraDocument.m`, `AXCServiceIconPackDocument.m`, `AXCStatusIconPackDocument.m`) compile with zero errors; the failures are entirely in the untouched Carbon sources.

## Repro

```
xcodebuild -project Other/XtrasCreator/XtrasCreator.xcodeproj \
  -target XtrasCreator -configuration Debug -sdk macosx \
  SYMROOT="$PWD/build/DerivedData/Build/Products" \
  OBJROOT="$PWD/build/DerivedData/Build/Intermediates" build
```

## Why deferred

- Outside the clean-break rename sprint's scope (shared subsystem was bundle-ID assignment + framework versioning, not XtrasCreator's build toolchain)
- Fixing it properly means porting away from the Carbon resource manager (`IconFamily.m` is a large, self-contained chunk) — that's a real sub-project needing its own design, not a drive-by fix
- XtrasCreator is a standalone helper app, not part of the shipped AdiumY.app

## Suggested approach (for a future sprint)

1. Replace the Carbon resource-file writes in `IconFamily.m` with the modern `NSImage`/`NSWorkspace`-based icon APIs (the file already has a Cocoa path for reading thumbnails; the Carbon path is legacy)
2. Port `NSString+CarbonFSSpecCreation` callers to `NSURL`/`NSFileManager`; the category itself can be deleted once no callers remain
3. Re-target the XtrasCreator project to a recent deployment target and verify the helper still produces valid `.AdiumXtra` bundles

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

