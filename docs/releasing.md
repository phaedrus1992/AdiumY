# Releasing AdiumY

Cutting a release means producing a `.dmg` that a stranger can download and
double-click without Gatekeeper complaining. `fastlane` drives the whole thing;
see `fastlane/Fastfile`.

Apple team: **K75Y6WZDVX**. Bundle ID: `com.github.phaedrus1992.adiumy`.

## TL;DR

```sh
bundle install
bundle exec fastlane mac preflight   # verifies credentials, costs seconds
git tag v2.0.0 && git push --tags    # CI does the rest
```

Or locally: `bundle exec fastlane mac release`.

## One-time setup

### 1. Developer ID Application certificate

Xcode → Settings → Accounts → team **K75Y6WZDVX** → Manage Certificates →
**+** → *Developer ID Application*.

Apple issues at most 5 of these per team, and revoking one invalidates
signatures on builds already in the wild. Export a backup immediately:
Keychain Access → right-click the certificate → Export → `.p12` with a strong
password. Store it in a password manager, not in this repo.

`fastlane` finds the identity by team ID; you never have to type its name.
Override with `DEVELOPER_ID_IDENTITY` if you have more than one.

### 2. App Store Connect API key

appstoreconnect.apple.com → Users and Access → Integrations → App Store
Connect API → **+**, role **Developer**.

The `.p8` downloads exactly once. Save it to
`~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` and note the Key ID and
Issuer ID.

This replaces `notarytool store-credentials` with an app-specific password: a
keychain profile cannot be transported to CI, an API key can.

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 3. Sparkle EdDSA keypair

```sh
bash Dependencies/build-phases/get-sparkle.sh
Dependencies/build/sparkle-tools/generate_keys
```

The private key goes into your login keychain; the public key is printed.
Paste the public key into `SUPublicEDKey` in `Resources/Info.plist`.

**This cannot be changed after the first release ships** — existing installs
would reject every future update. `fastlane mac preflight` refuses to run while
`SUPublicEDKey` is empty.

## GitHub Actions secrets

`.github/workflows/release.yml` runs on any `v*` tag. It needs:

| Secret | Contents |
|---|---|
| `DEVELOPER_ID_P12` | `base64 -i DeveloperID.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | the `.p12` export password |
| `ASC_KEY_P8` | `base64 -i AuthKey_<KEY_ID>.p8` |
| `ASC_KEY_ID` | App Store Connect Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `SPARKLE_PRIVATE_KEY` | private key from `generate_keys` |

```sh
gh secret set DEVELOPER_ID_P12 < <(base64 -i DeveloperID.p12)
```

The release job uses no caches. `ci.yml` runs on pull requests and writes the
dependency and bundler caches, so a malicious PR could otherwise poison a cache
and have the result end up inside a signed, notarized build. Everything in a
release is compiled from source, which is why the job takes about an hour.

## Lanes

Each lane runs alone, so a failed release resumes rather than restarts.

| Lane | Does |
|---|---|
| `preflight` | Verifies certificate, API key, and `SUPublicEDKey`. Run this first. |
| `build` | Vendored deps → `MMTabBarView.framework` → `xcodebuild -configuration Release` |
| `sign` | `Release/sign-bundle.sh`: inside-out signing, hardened runtime, entitlements, verification |
| `notarize_app` | Submit, wait, staple, confirm Gatekeeper accepts |
| `package` | `Release/make-dmg.sh`, then sign + notarize + staple the DMG |
| `appcast` | `generate_appcast` with the EdDSA key |
| `publish` | GitHub Release with the DMG, plus `appcast.xml` committed to `main` |
| `release` | All of the above |

`VERSION` is read from the current git tag. Override with `VERSION=2.0.0`.

## How signing works here

Signing is applied to the finished bundle, not baked into the Xcode project.
`Adium.xcodeproj` keeps `CODE_SIGN_IDENTITY = "-"`, so contributors without the
certificate can still build and PR builds stay unsigned. Hardened runtime
(`-o runtime`) and entitlements are `codesign` flags, applied by
`Release/sign-bundle.sh` after every architecture slice is assembled.

`--deep` is not used. It forces one set of options and entitlements onto every
nested item and skips non-standard locations. `sign-bundle.sh` walks the bundle
deepest-first instead, then signs the outer `.app` last, then audits every
executable and fails if any is unsigned.

`Adium.entitlements` carries `com.apple.security.cs.disable-library-validation`
because hardened-runtime apps refuse to load dylibs signed by another team, and
AdiumY loads libpurple and a dozen other vendored libraries.

## Verifying a release by hand

```sh
codesign --verify --strict --deep -vv AdiumY.app
spctl -a -vv AdiumY.app            # must say "accepted", "Notarized Developer ID"
xcrun stapler validate AdiumY.app
lipo -archs AdiumY.app/Contents/MacOS/AdiumY   # arm64 x86_64
```

The only test that really counts: download the DMG from the GitHub Release on a
Mac that has never built AdiumY, and launch it.

## When notarization fails

`fastlane` fetches the notary log automatically and prints the per-file
reasons. The usual causes:

- **"not signed with a valid Developer ID certificate"** — an ad-hoc or
  Apple Development identity survived somewhere in the bundle.
- **"does not include a secure timestamp"** — something was signed without
  `--timestamp`, usually by a build phase rather than `sign-bundle.sh`.
- **"hardened runtime not enabled"** — same, missing `-o runtime`.

Re-run `bundle exec fastlane mac sign` and check its per-file output.

## Related

- `docs/signing-notarization.md` — background on Gatekeeper and the identity tiers
- `Utilities/README-appcast.md` — Sparkle appcast details
