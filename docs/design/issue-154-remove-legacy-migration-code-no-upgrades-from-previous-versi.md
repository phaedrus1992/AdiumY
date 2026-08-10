# Design: Remove legacy migration code (no upgrades from previous versions)

- **Issue:** [#154 — Remove legacy migration code (no upgrades from previous versions)](../../../../issues/154)
- **Status:** Proposed

## 1. Summary

Found during the #122 clean-break audit. AdiumY 2.0 is the first release with **no upgrade path from any previous version** — nobody is coming from Adium 1.x. **Keep the upgrade mechanism** (the gated, one-time preference-upgrade pattern is infrastructure we'll need again for real future upgrades) but **remove the obsolete pre-fork migration data** that exists only to upgrade preferences/data written by Adium releases nobody has.

### Remove (obsolete pre-fork migration data)
- `Plugins/WebKit Message View/AIWebKitMessageViewPlugin.m` — the legacy `im.adium.*` → AdiumY style-bundle-ID `conversionDict` inside `performAdium14PreferenceUpdates` (gate key `@"Adium 1.4:Updated Preferences"`)
- `Source/AdiumPasswords.m` — `@"Adium 1.3: Account Passwords Upgraded"` keychain migration
- `Source/AdiumAccounts.m` — `@"Adium:Account Prefs Upgraded for 1.0"` account-prefs migration
- `Source/AIURLHandlerPlugin.h` — `@"AdiumURLHandling:CompletedFirstLaunch"` first-launch flag (if only used as an upgrade gate)
- `Plugins/Purple Service/SLPurpleCocoaAdapter.m` + `Source/AIAdium.m` — `@"Adium 1.2.4 deleted blist.xml"`, `@"Adium 1.0.3 moved to libpurple"` libpurple data-dir migrations
- `Source/AILoggerPlugin.m` + `Source/AIAdium.m` — `@"Adium 1.3.3:Reimported Spotlight Logs"` log-reimport migration
- `Source/AIDockController.m` — `@"Adium:Last Icon Update Version"` dock-icon migration
- `Source/AdiumSoundSets.m` — `AdiumSetVersion` / `AdiumSetPathname_Private` soundset migration keys

### Keep (upgrade mechanism, valuable for future)
The general one-time, flag-gated preference-upgrade pattern (`perform…PreferenceUpdates` + a `"…:Updated"` gate key) — reuse it when a real AdiumY 2.x→3.x upgrade needs to migrate preferences. Don't delete the infrastructure, only the pre-fork entries above.

### Also evaluate (not strictly migration maps, but pre-2.0 legacy)
The Keychain storage scheme `Adium.%@` in `Source/AdiumPasswords.m`, the `AdiumProxyType` preference key, and the `im.adium.*` style identifiers still present as migration input.

Rule of thumb: any key/map whose only purpose is reading a value written by a previous Adium release can be deleted; if a live code path reads/writes it at runtime (not just for upgrade), it stays.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

