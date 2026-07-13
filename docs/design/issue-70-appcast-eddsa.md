# Design: Replace md5-signed appcast tooling with Sparkle 2 EdDSA signing

- **Issue:** [#70 — AppcastReplaceItem.py signs with md5Sum, needs EdDSA for Sparkle 2.x](../../../../issues/70)
- **Status:** Proposed
- **Scope:** `Utilities/AppcastReplaceItem.py` (delete), `Resources/Info.plist` (add one key), release documentation

## 1. Problem

`Utilities/AppcastReplaceItem.py` rewrites an appcast `<item>` for a new release and
stamps the enclosure with `sparkle:md5Sum` (line 13). The vendored Sparkle is 2.9.4
(`Frameworks/Sparkle.framework`), which ignores `md5Sum` entirely and validates
updates with EdDSA (Ed25519) signatures in a `sparkle:edSignature` attribute.
An appcast produced by this script will fail Sparkle 2 signature validation.

Additional problems with the script, found on inspection:

- It is Python 2 (`file()` builtin at lines 61/90, implicit-bytes handling). It cannot
  run at all under any Python shipped on modern macOS.
- It hard-codes dead infrastructure: `https://github.com/phaedrus1992/adiumy/` download URL
  (line 58) and `https://github.com/phaedrus1992/adiumy/changelogs/` release-notes URL (line 12).
- Nothing else in the tree references it (`rg -l AppcastReplaceItem` finds only the
  script itself). It is standalone release tooling.

Related gap (must be fixed together or updates can never validate): the active app
Info.plist (`Resources/Info.plist`, selected by `INFOPLIST_FILE` in
`Adium.xcodeproj/project.pbxproj`) contains **no Sparkle keys at all**. The legacy
`Resources/Info copy.plist` has `SUFeedURL`, `SUPublicDSAKeyFile` (DSA — also a
Sparkle 1.x mechanism, removed in 2.x), `SUCheckAtStartup`, and
`SUScheduledCheckInterval`. Wiring the feed/public key back into the active plist is
tracked as part of this issue because an EdDSA-signed appcast is useless without
`SUPublicEDKey` in the app.

## 2. Design

Delete the script and use Sparkle's own release tooling. Sparkle 2 ships two CLI
tools in its distribution archive (not inside the framework bundle itself):

- `generate_keys` — creates an Ed25519 keypair, stores the private key in the
  login Keychain, prints the base64 public key.
- `generate_appcast` — given a directory of release archives (`.dmg`/`.zip`/etc.),
  writes/updates `appcast.xml` with correct `sparkle:edSignature`, `length`,
  `sparkle:version`, and `pubDate` — everything AppcastReplaceItem.py did, done
  correctly.

Writing our own EdDSA signing in Python would duplicate `generate_appcast` with
more code and more ways to get it wrong. Don't.

### 2.1 Steps

1. **Obtain the tools.** `Dependencies/get-sparkle.sh` already fetches the Sparkle
   distribution. Extend it (or document alongside it) so `bin/generate_appcast`,
   `bin/generate_keys`, and `bin/sign_update` from the same Sparkle release land in
   `Dependencies/build/sparkle-tools/` (any gitignored location is fine). The tool
   version must match the vendored framework version (2.9.4) — take it from the
   same archive get-sparkle.sh downloads.

2. **Generate the signing key** (one-time, done by the release manager, NOT in CI
   and NOT committed):

   ```
   ./generate_keys
   ```

   This stores the private key in the login Keychain and prints the public key.

3. **Add the public key + feed URL to the active Info.plist**
   (`Resources/Info.plist`):

   ```xml
   <key>SUPublicEDKey</key>
   <string><!-- base64 output of generate_keys --></string>
   <key>SUFeedURL</key>
   <string><!-- current appcast URL; the github.com/phaedrus1992/adiumy one in "Info copy.plist" is a
        placeholder until the fork has its own feed --></string>
   ```

   Use `plutil`/PlistBuddy, not text editing. If the fork has no update feed yet,
   still add `SUPublicEDKey` now and leave `SUFeedURL` for when a feed exists —
   an appcast signed before the key ships in the app is fine; the reverse is not.

4. **Delete `Utilities/AppcastReplaceItem.py`.** Replace with a short
   `Utilities/README-appcast.md` (or a section in existing release docs) showing
   the invocation:

   ```
   generate_appcast /path/to/release-archives/
   ```

   `generate_appcast` maintains the whole appcast file across releases, so the
   "replace one item" workflow the Python script implemented disappears.

### 2.2 What NOT to do

- Do not port the script to Python 3 and bolt on `sign_update` — that keeps dead
  URL constants and a hand-rolled XML line parser alive for no benefit.
- Do not commit any private key material, and do not configure Sparkle to skip
  signature validation.

## 3. Verification

1. `generate_keys` output pasted into `Resources/Info.plist`; `plutil -lint
   Resources/Info.plist` passes.
2. Run `generate_appcast` against a directory containing one test `.dmg`; confirm
   the emitted `<enclosure>` has `sparkle:edSignature` and `length`, and no
   `sparkle:md5Sum`.
3. `sign_update --verify` (or `sign_update -p` comparison) validates the enclosure
   signature against the public key.
4. `rg -l "AppcastReplaceItem|md5Sum"` in the repo returns nothing.

## 4. Out of scope

- Runtime `SUUpdater` → `SPUUpdater` migration in the app: issue #69.
- The crash reporter's Sparkle usage: issue #68.
- Standing up an actual update feed/host for the fork.
