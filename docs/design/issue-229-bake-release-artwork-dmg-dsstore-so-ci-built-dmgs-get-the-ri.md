# Design: Bake Release/Artwork/dmg-DS_Store so CI-built DMGs get the right window layout

- **Issue:** [#229 — Bake Release/Artwork/dmg-DS_Store so CI-built DMGs get the right window layout](../../../../issues/229)
- **Status:** Implemented (sprint #309)

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

Baked on a Mac with a GUI session, then committed:

1. Ran `make-dmg.sh`'s AppleScript path once on a session Mac. Finder laid out
   the window (bounds `{200, 120, 800, 520}` — the exact 600×400 background at
   the standard top-left margin, icons at their positions) and wrote the result
   into the mounted volume's `.DS_Store`.
2. Copied the mounted volume's `.DS_Store` out to
   `Release/Artwork/dmg-DS_Store` (10244 bytes) and committed it.
3. `make-dmg.sh` already prefers the pre-baked file (added in sprint #306):
   `if [ -f "$RELEASE_DIR/Artwork/dmg-DS_Store" ]` → `ditto` it into
   `$MOUNT_DIR/.DS_Store` and skip the AppleScript path entirely. Every
   subsequent build — headless runner or not — applies the identical layout
   with no Finder dependency.

The regeneration caveat from the summary stands: `.DS_Store` records item
*names* and positions, not content, so it must be regenerated if the app
bundle or the text files (`Changes.txt`, `License.txt`) are ever renamed.
This is also why a stub app is sufficient for baking — only the names matter.

## 3. Verification

- [x] Verified with the mock-tool harness (`hdiutil`/`SetFile` mocked, real
  `ditto`): the pre-baked path engages (no `osascript` invocation), the
  committed `.DS_Store` lands on the volume root byte-identical, and the
  end-of-run layout warning does not fire. Also verified byte-for-byte
  identity (`shasum eecc792386b46d8753fedfa17ba78c3b15c594cd`) against the
  baked source.

