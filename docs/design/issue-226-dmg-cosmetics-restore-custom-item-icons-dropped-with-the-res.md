# Design: DMG cosmetics: restore custom item icons dropped with the resource-fork artwork

- **Issue:** [#226 — DMG cosmetics: restore custom item icons dropped with the resource-fork artwork](../../../../issues/226)
- **Status:** Implemented (sprint #309)

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

Volume root icon via the modern mechanism, no resource forks:

1. Committed `Release/Artwork/VolumeIcon.icns`, copied from
   `Resources/Adium.icns` (the app's own icon) — the artwork that ships in
   the DMG.
2. `make-dmg.sh` applies it right after mounting the read-write image, before
   `chmod -Rf go-w`:
   - `ditto` `$RELEASE_DIR/Artwork/VolumeIcon.icns` to
     `$MOUNT_DIR/.VolumeIcon.icns`, then set the custom-icon attribute with
     `SetFile -a C "$MOUNT_DIR"`.
   - A missing icon (ditto fails on the absent source) or a `SetFile` failure
     prints a warning and continues — the icon is cosmetic and must never fail
     a release. No `[ -f ]` guard: an absent icon degrades to the same ditto
     warning rather than skipping silently.
3. Finder renders the custom icon for the mounted disk from
   `.VolumeIcon.icns` + the `-a C` attribute. This replaces the HFS+
   resource-fork `Icon\r` artwork (`CustomIcons.tgz`) that git cannot store;
   the old fork art is not reintroduced.

## 3. Verification

- [x] Verified with the mock-tool harness (real `hdiutil attach -readwrite` is
  unavailable in a non-GUI/headless context): the committed `.VolumeIcon.icns`
  lands on the volume root byte-identical and `SetFile -a C` is invoked with
  the mount path. Missing-icon (warning emitted, no `SetFile` call) and
  `SetFile`-failure (warning, non-fatal) paths both behave. Exercised
  end-to-end by the GUI-session release pipeline on first release.

