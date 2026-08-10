# Design: get-sparkle.sh downloads Sparkle with no checksum verification

- **Issue:** [#255 — get-sparkle.sh downloads Sparkle with no checksum verification](../../../../issues/255)
- **Status:** Proposed

## 1. Summary

Found during pre-pr-review of #228 (fastlane release pipeline, #118).

`Dependencies/build-phases/get-sparkle.sh` curls a prebuilt Sparkle.xcframework
and the `generate_appcast`/`generate_keys`/`sign_update` CLI tools with no
checksum verification and no `curl --fail`. Both land inside the notarized
release, and `generate_appcast` is later handed the Sparkle private key
(`fastlane mac appcast`).

`release.yml` deliberately uses no caches so "everything is built from
source" — this is the one dependency in the release path that isn't, and the
no-checksum download undermines that guarantee. Pre-existing file, not
introduced by #228; worth pinning a checksum or a specific release tag rather
than fetching latest.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

