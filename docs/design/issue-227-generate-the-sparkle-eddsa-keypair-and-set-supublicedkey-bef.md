# Design: Generate the Sparkle EdDSA keypair and set SUPublicEDKey before the first release

- **Issue:** [#227 — Generate the Sparkle EdDSA keypair and set SUPublicEDKey before the first release](../../../../issues/227)
- **Status:** Accepted (shipped)

## 1. Summary

Blocks #118.

`Resources/Info.plist` sets `SUFeedURL` to
`https://raw.githubusercontent.com/phaedrus1992/AdiumY/main/appcast.xml`.
The release pipeline signs the appcast with a Sparkle EdDSA private key.
Sparkle verifies that signature against `SUPublicEDKey`.

Before this work, `SUPublicEDKey` was an empty string, so Sparkle could not
verify an update even when the feed existed. `bundle exec fastlane mac
preflight` failed while the key was empty, so a release could not go out.

`SUPublicEDKey` cannot change after the first release ships. Every existing
install would reject all future updates.

AdiumY 2.0.0 does not link Sparkle (#128), so the app does not verify an
update yet. The key and the secret are still required. The release pipeline
signs the appcast with them, and the public key must be fixed before the first
release that ships with a working updater.

## 2. Approach

1. Run `Dependencies/build/sparkle-tools/generate_keys` to create the keypair.
   The private key stays in the login keychain.
2. Paste the printed public key into `SUPublicEDKey` in `Resources/Info.plist`.
3. Add the private key as the `SPARKLE_PRIVATE_KEY` GitHub secret, so the
   release workflow can sign the appcast.

The committed public key is
`fmk7kzjP1kO1OCYsk12tyUnzdrFbvyoFhYqkLkOZdPo=`.

## 3. Verification

- [x] `Resources/Info.plist` `SUPublicEDKey` is a non-empty value
- [x] The `SUFeedURL` points at the published appcast path
- [x] The `SPARKLE_PRIVATE_KEY` GitHub secret exists
