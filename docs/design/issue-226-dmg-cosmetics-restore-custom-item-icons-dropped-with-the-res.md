# Design: DMG cosmetics: restore custom item icons dropped with the resource-fork artwork

- **Issue:** [#226 — DMG cosmetics: restore custom item icons dropped with the resource-fork artwork](../../../../issues/226)
- **Status:** Proposed

## 1. Summary

Part of #118.

`Release/Artwork/CustomIcons.tgz` held HFS+ resource-fork icons (`Icon\r` files
for the app, the Applications alias, and the text files) that the pre-fork DMG
script applied to the mounted volume. It was removed alongside
`make-diskimage.sh`, which needed an i386-only `AdiumApplescriptRunner` to run
`dmg_adium.scpt`.

`Release/make-dmg.sh` keeps the background image and the Finder window layout,
which is what people actually see, but the individual items now use their
default icons.

Restoring this on modern macOS means a `.VolumeIcon.icns` plus `SetFile -a C`
on the volume root, not resource forks. Purely cosmetic — this does not block a
release.

The old artwork is recoverable from git history:
`git show 51ad8980^:Release/Artwork/CustomIcons.tgz`

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

