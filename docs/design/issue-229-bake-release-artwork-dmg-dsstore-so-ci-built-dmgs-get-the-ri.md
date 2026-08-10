# Design: Bake Release/Artwork/dmg-DS_Store so CI-built DMGs get the right window layout

- **Issue:** [#229 — Bake Release/Artwork/dmg-DS_Store so CI-built DMGs get the right window layout](../../../../issues/229)
- **Status:** Proposed

## 1. Summary

Part of #118.

`Release/make-dmg.sh` sets the disk image window size, background and icon
positions by driving Finder over AppleScript. That needs a GUI login session,
which a GitHub Actions runner does not have, so on CI the step warns and the
DMG ships with default icon positions.

The script already prefers a pre-baked `.DS_Store` when one exists:

```sh
DS_STORE="$RELEASE_DIR/Artwork/dmg-DS_Store"
```

To produce it: build a DMG locally (the AppleScript path runs fine on a Mac
with a session), mount it, and copy the resulting `.DS_Store` out:

```sh
bundle exec fastlane mac package
hdiutil attach build/dist/AdiumY-<version>.dmg
cp "/Volumes/AdiumY <version>/.DS_Store" Release/Artwork/dmg-DS_Store
```

Commit that file. Every subsequent build, headless or not, then gets an
identical layout with no Finder dependency — which is also what the pre-fork
`Release/RightDS_Store` was for.

Caveat: `.DS_Store` records item names, so it has to be regenerated if the app
bundle or the text files are ever renamed.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

