# Design: Restore or document removal of Sparkle auto-updater (no security-patch delivery)

- **Issue:** [#128 — Restore or document removal of Sparkle auto-updater (no security-patch delivery)](../../../../issues/128)
- **Status:** Accepted (option 2 shipped; Sparkle restore deferred)

## 1. Summary

**Severity:** P1 (from pre-pr-review)

The `Sparkle.framework` remains physically bundled, linked, and copied into the app (project.pbxproj), but all calling code has been removed:
- `SPUStandardUpdaterController` instance in `Resources/MainMenu.xib`
- `updaterController` IBOutlet
- `SPUUpdaterDelegate` conformance on `Source/AIAdium.h` / the `feedParametersForUpdater:sendingSystemProfile:` method in `AIAdium.m`
- Check For Updates menu item in `AIMenuController`

Sparkle 2 requires explicit init via `SPUStandardUpdaterController` — it does not auto-start from Info.plist keys alone. Net effect: **zero mechanism to notify users of or deliver security patches.** Adium processes untrusted network data (XMPP, IRC, file transfers, link previews) and is a historical remote-exploitation target.

**Options:**
1. Restore the Sparkle wiring (nib instance, outlet, delegate, menu item) — simplified for the fork.
2. Document the intentional removal: add a prominent security note to the README and remove the dead `Sparkle.framework` reference + copy build phase to avoid confusion.

## 2. Approach

The recorded decision on the issue is option 2. Sparkle returns with the
distribution work; until then the bundle must not imply update support.

This change does the following:

1. Remove the six `Sparkle.framework` entries from
   `Adium.xcodeproj/project.pbxproj`: the `Frameworks` link, the `Copy Frameworks`
   build file and its phase entry, the `PBXFileReference`, and the group child.
2. Add an "Updates and Security Patches" section to `README.md`.
3. Correct the stale Sparkle comments in `fastlane/Fastfile` and `.gitignore`.

The `get-sparkle.sh` download stays. The appcast lane still uses its CLI tools,
and the restore needs the framework.

### Restore requirements (open on this issue, not done in this change)

- Re-add the link and the copy phase. Re-add the `SPUStandardUpdaterController`
  nib object, the `updaterController` outlet, and the "Check For Updates..."
  menu item (commit `c8540427` shows the removed code).
- Bump the vendored Sparkle from 2.9.4 to 2.10.0. Version 2.9.4 carries three
  open advisories, fixed in 2.9.5 and 2.9.6: GHSA-3x7w-j75x-ppq5 (high),
  GHSA-4v99-qgq9-6pxp (high), and GHSA-gmj2-gq3j-vqmj (medium).
  Version 2.10.0 needs macOS 12.0, which matches the deployment target.
- Re-pin both SHA256 constants in `Dependencies/build-phases/get-sparkle.sh`
  when the version changes.
- Re-check the `feedParametersForUpdater:sendingSystemProfile:` delegate method.
  The static GitHub-raw appcast does not use its feed parameters, so the restore
  may omit it.

## 3. Verification

- [x] `plutil -lint Adium.xcodeproj/project.pbxproj` reports OK
- [x] `xcodebuild -list -project Adium.xcodeproj` lists all targets
- [x] No `Sparkle` reference remains in `Adium.xcodeproj/project.pbxproj`
- [ ] CI build passes and the built bundle has no `Sparkle.framework`

