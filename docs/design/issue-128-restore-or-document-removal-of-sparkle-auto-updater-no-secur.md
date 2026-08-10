# Design: Restore or document removal of Sparkle auto-updater (no security-patch delivery)

- **Issue:** [#128 — Restore or document removal of Sparkle auto-updater (no security-patch delivery)](../../../../issues/128)
- **Status:** Proposed

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

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

