# Design: Generate the Sparkle EdDSA keypair and set SUPublicEDKey before the first release

- **Issue:** [#227 — Generate the Sparkle EdDSA keypair and set SUPublicEDKey before the first release](../../../../issues/227)
- **Status:** Proposed

## 1. Summary

Blocks #118.

`Resources/Info.plist` now has a real `SUFeedURL`
(`https://raw.githubusercontent.com/phaedrus1992/AdiumY/main/appcast.xml`) but
`SUPublicEDKey` is still an empty string, so Sparkle cannot verify an update
even once the feed exists.

```sh
bash Dependencies/build-phases/get-sparkle.sh
Dependencies/build/sparkle-tools/generate_keys
```

The private key lands in the login keychain; paste the printed public key into
`SUPublicEDKey`, and add the private key as the `SPARKLE_PRIVATE_KEY` GitHub
secret so the release workflow can sign the appcast.

**This value cannot change after the first release ships** — every existing
install would reject all future updates.

`bundle exec fastlane mac preflight` fails while the key is empty, so a release
cannot go out without it. Closing this issue means the key is generated,
committed, and stored as a secret.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

