# Signing and Notarization for Distribution

How to ship AdiumY binaries that launch cleanly for people who download them.
This covers Apple code signing + notarization (Gatekeeper). Sparkle update-feed
signing is separate — see `Utilities/README-appcast.md`.

## TL;DR

You need a paid **Apple Developer Program** account ($99/year; Individual is
fine, no D-U-N-S needed). One account covers all your projects. There is no free
or open-source path to a cleanly-launching third-party binary on macOS.

## Why a paid account is required

- Notarization — mandatory since macOS Catalina (10.15) for software
  distributed outside the App Store — only accepts a **Developer ID
  Application** certificate.
- That certificate is only issued to paid Developer Program members.
- A free Apple ID only issues "Apple Development" certificates for local
  development; notarization rejects them.
- No self-signed or ad-hoc identity passes Gatekeeper for downloaded copies.

## The three tiers

| Signing | End-user experience | Cost |
|---|---|---|
| Unsigned | arm64: won't launch at all (kernel kills it). Intel: "unidentified developer" warning | $0 |
| Ad-hoc (`codesign -s -`) | Launches on arm64, but Gatekeeper still blocks a downloaded copy | $0 |
| Developer ID + notarize + staple | Clean launch, no warning | $99/yr |

arm64 macOS refuses to run unsigned binaries. The linker ad-hoc-signs at link
time, so a *locally built* app runs — but any downloaded copy (quarantine
attribute) hits Gatekeeper with "Apple cannot check it for malicious software" /
"damaged" / "unidentified developer". Right-click → Open is the manual bypass,
not something to ship.

## Current state of this repo

- Apple team **K75Y6WZDVX**. Releases are signed, notarized and stapled by
  `fastlane` — see **`docs/releasing.md`**, which is the operational guide.
  This file is the background on *why* each step exists.
- PR builds (`.github/workflows/ci.yml`) still use `CODE_SIGNING_ALLOWED=NO`
  and are deliberately unsigned; don't hand those to users.
- App product name is `AdiumY` (universal arm64+x86_64); sign the finished fat
  binary once, after all slices are assembled.

## The manual equivalent of what fastlane does

### 1. One-time: store notarization credentials

The release pipeline uses an App Store Connect API key (`.p8`) instead, because
a keychain profile cannot be transported to CI. For one-off local work:

```sh
xcrun notarytool store-credentials AC --apple-id you@example.com --team-id TEAMID
```

Prompts for an app-specific password (create one at appleid.apple.com).

### 2. Sign the bundle inside-out

Sign nested code first, outer bundle last. `--deep` is deprecated — it forces
one set of options/entitlements onto every nested item and misses non-standard
locations.

```sh
ID="Developer ID Application: Your Name (TEAMID)"
codesign -f --timestamp -o runtime -s "$ID" \
    AdiumY.app/Contents/Frameworks/Sparkle.framework
# repeat for every nested binary: frameworks, XPC services, dylibs
codesign -f --timestamp -o runtime -s "$ID" \
    --entitlements AdiumY.entitlements AdiumY.app
```

- `--timestamp` (secure timestamp) and `-o runtime` (hardened runtime) are both
  **required** for notarization.
- Entitlements go on executables (main app, helpers), not on frameworks or plain
  dylibs.

### 3. Notarize and staple

```sh
ditto -c -k --keepParent AdiumY.app AdiumY.zip
xcrun notarytool submit AdiumY.zip --keychain-profile AC --wait
xcrun notarytool log <submission-id>   # on "Invalid": per-file reasons
xcrun stapler staple AdiumY.app
```

Staple the `.app` (or `.dmg`/`.pkg`) — a `.zip` cannot be stapled; re-zip AFTER
stapling for distribution. If shipping a DMG, sign and notarize the DMG too.

### 4. Verify

```sh
codesign --verify --strict --deep -vv AdiumY.app   # seal + nested code
spctl -a -vv AdiumY.app                            # Gatekeeper verdict
# audit every executable:
find AdiumY.app -type f -perm +111 -exec codesign --verify {} \;
```

## AdiumY-specific notes

- **Hardened runtime + library validation**: hardened-runtime apps refuse dylibs
  signed by a different team (or ad-hoc) unless
  `com.apple.security.cs.disable-library-validation` is set. AdiumY drags in
  libpurple and other third-party dylibs, so expect to need that entitlement.
- **Universal binaries**: `codesign` signs all slices at once, but any later
  edit (`install_name_tool`, `lipo`, `strip`) invalidates the signature —
  re-sign after patching.
- **CI**: `.github/workflows/release.yml` runs on `v*` tags and holds the
  certificate and API key as GitHub secrets, so a release does not depend on
  one developer's laptop. Secret names are listed in `docs/releasing.md`.

## Common notarization rejections

- "not signed with a valid Developer ID certificate" — ad-hoc or Development
  identity somewhere in the bundle.
- "does not include a secure timestamp" — missing `--timestamp`.
- "hardened runtime not enabled" — missing `-o runtime` on some binary.
- Unsigned nested binary — audit every executable (step 4).

## Related

- `docs/releasing.md` — the actual release procedure and credential setup.
- `Utilities/README-appcast.md` — Sparkle appcast (EdDSA) release signing.
- llmenv `mac-dev` bundle, `rules/signing-notarization.md` — same guidance.
