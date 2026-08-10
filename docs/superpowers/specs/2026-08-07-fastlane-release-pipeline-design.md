# fastlane Release Pipeline — Design

Issue: #118 (Binary Releases), milestone v2.0.0.

Ship a signed, notarized, auto-updating AdiumY build that a stranger can
download and double-click. Runs identically on a maintainer's Mac and on a
GitHub Actions runner.

## Goal

`fastlane release` takes a clean checkout at a version tag and produces:

1. `AdiumY.app` — Developer ID signed, hardened runtime, notarized, stapled
2. `AdiumY-<version>.dmg` — signed, notarized, stapled
3. `appcast.xml` — EdDSA-signed Sparkle feed entry
4. A GitHub Release with the DMG attached

## Current state

- `.github/workflows/ci.yml` builds with `CODE_SIGNING_ALLOWED=NO`. Artifacts
  are unsigned and Gatekeeper blocks them for anyone who downloads one.
- `Release/Makefile` is the pre-fork release driver. It is dead: it pulls with
  mercurial (`hg pull -u`), signs with the deprecated `--deep`, and hardcodes
  `Developer ID Application: Instant Messaging Freedom, Inc.` (team
  `VQ6ZEL8UD3`, which this fork has no access to). The DMG half —
  `make-diskimage.sh`, `dmg_adium.scpt`, `Artwork/` — still works and is kept.
- `Resources/Info.plist` has `SUFeedURL` and `SUPublicEDKey` set to empty
  strings. Sparkle is linked but auto-update is not actually configured.
- `Adium.entitlements` exists and already carries
  `com.apple.security.cs.disable-library-validation` (libpurple and the other
  vendored dylibs need it under hardened runtime), but no target references it.
- Apple team is `C36L3X7U5T`. Bundle ID `com.github.phaedrus1992.adiumy`.
  Universal via `ARCHS_STANDARD`; deployment target 12.0.

## Design

### Signing happens after the build, not during it

The Xcode project keeps `CODE_SIGN_IDENTITY = "-"` (ad-hoc). fastlane re-signs
the finished bundle inside-out with the Developer ID identity, applying
`--entitlements Adium.entitlements` and `-o runtime` at `codesign` time.

Rationale: contributors without the certificate must still be able to build,
and `ci.yml` PR builds stay unsigned. Baking `DEVELOPMENT_TEAM`,
`CODE_SIGN_ENTITLEMENTS`, and `ENABLE_HARDENED_RUNTIME` into the xcconfigs
would break both. Hardened runtime and entitlements are `codesign` flags, so
applying them in the signing lane is equivalent and has a smaller blast radius.
This also matches `docs/signing-notarization.md`: sign the finished universal
bundle once, after every slice is assembled.

Consequence: the only source change this design makes outside `fastlane/` and
CI is filling in the two Sparkle keys.

### Credentials: App Store Connect API key, not an app-specific password

`notarytool` accepts a `.p8` API key. One key works unchanged locally and on a
runner, needs no 2FA prompt, and is revocable without touching the Apple ID.
The alternative (`notarytool store-credentials` with an app-specific password)
creates a keychain profile that cannot be transported to CI.

| | Local | CI |
|---|---|---|
| Developer ID cert | login keychain | `DEVELOPER_ID_P12` (base64) + `DEVELOPER_ID_P12_PASSWORD`, imported into a temp keychain |
| ASC API key | `~/.appstoreconnect/private_keys/AuthKey_<id>.p8` | `ASC_KEY_P8` (base64) + `ASC_KEY_ID` + `ASC_ISSUER_ID` |
| Sparkle EdDSA key | login keychain | `SPARKLE_PRIVATE_KEY` |
| GitHub token | `gh auth` | `GITHUB_TOKEN` |

`match` was considered and rejected. Developer ID Application certificates are
capped at 5 per team and revoking one invalidates signatures on already-shipped
builds; match's create/revoke cycle is a liability for a single maintainer. The
cert lives in the login keychain with an encrypted `.p12` backup.

### Lanes

Each lane is runnable alone so a failed release can be resumed rather than
restarted.

| Lane | Input | Output |
|---|---|---|
| `build` | clean checkout | `build/Release/AdiumY.app` (ad-hoc signed) |
| `sign` | `.app` | same `.app`, Developer ID signed inside-out, verified |
| `notarize` | signed `.app` | stapled `.app` |
| `package` | stapled `.app` | signed, notarized, stapled `.dmg` |
| `appcast` | `.dmg` | `appcast.xml` with `sparkle:edSignature` |
| `publish` | `.dmg` + `appcast.xml` | GitHub Release, `appcast.xml` committed |
| `release` | version tag | all of the above |

`build` shells out to the same sequence `ci.yml` already uses (vendored deps →
`MMTabBarView.framework` → `xcodebuild -configuration Release`). It does not
use `gym`. This build is driven by `Dependencies/build-*.sh` and a framework
copy step; `gym`'s archive/export model fights that for no benefit.

`sign` walks the bundle bottom-up — frameworks, `.mdimporter` bundles,
`Contents/Resources/AdiumApplescriptRunner`, any nested dylib — then the outer
`.app` last with entitlements. `--deep` is not used: it forces one set of
options onto every nested item and misses non-standard locations. The lane ends
with `codesign --verify --strict` and `spctl -a -vv`, and fails the build if
either does.

`notarize` zips with `ditto -c -k --keepParent`, submits with `--wait`, and
staples the `.app`. A `.zip` cannot be stapled, so distribution artifacts are
always re-created after stapling.

### Sparkle feed

`appcast.xml` is committed to `main`; `SUFeedURL` is
`https://raw.githubusercontent.com/phaedrus1992/AdiumY/main/appcast.xml`.
Sparkle needs a static file over HTTPS and nothing more, so this avoids a
`gh-pages` branch and any hosting cost. DMGs are GitHub Release assets.

`SUPublicEDKey` is filled from `generate_keys` output. Changing either key
later requires shipping a new build, so both are set before the first release.

### CI

New `.github/workflows/release.yml`, triggered on `v*` tag push, calls
`fastlane release`. `ci.yml` is untouched — PR builds stay unsigned.

`Gemfile` pins fastlane 2.237.0 so the maintainer's Mac and the runner agree.
The current install is Homebrew-managed and will drift.

## Non-goals

- Mac App Store distribution. Developer ID only.
- Notarizing PR builds. Notarization is a network round trip to Apple measured
  in minutes; it belongs on tags.
- Reviving the nightly-build path in `Release/Makefile`.

## Verification

- `codesign --verify --strict -vv AdiumY.app` — seal and nested code
- `spctl -a -vv AdiumY.app` — Gatekeeper verdict, must say `accepted`
- Every executable: `find AdiumY.app -type f -perm +111 -exec codesign --verify {} \;`
- `xcrun stapler validate AdiumY.app` and the `.dmg`
- End-to-end: download the DMG from the GitHub Release on a machine that has
  never built AdiumY, and launch it. That is the only test that matters for #118.
