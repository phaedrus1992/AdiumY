# Design: get-sparkle.sh downloads Sparkle with no checksum verification

- **Issue:** [#255 — get-sparkle.sh downloads Sparkle with no checksum verification](../../../../issues/255)
- **Status:** Resolved

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

Pin both downloaded artifacts to fixed SHA-256 checksums, and make the checksum
the thing the build fails on — not a best-effort warning.

1. **Pin checksums as constants** next to `SPARKLE_VERSION` in
   `Dependencies/build-phases/get-sparkle.sh`:
   `SPARKLE_FRAMEWORK_SHA256` (the `Sparkle-for-Swift-Package-Manager.zip`
   XCFramework) and `SPARKLE_CLI_SHA256` (the `Sparkle-2.9.4.tar.xz` CLI
   tarball). The Sparkle 2.9.4 release body ships no checksums, so both values
   were computed by downloading the exact release assets (byte sizes matched
   the release asset sizes) and running `shasum -a 256`. A comment next to each
   constant tells the next version-bumper to re-pin both.
2. **Verify with `shasum -a 256 -c -`** after each `curl`: feed the pinned
   checksum + downloaded file to `shasum`, which exits non-zero on mismatch.
   Under `set -e` / `set -o pipefail` a bad download now aborts the build
   before the artifact is extracted or installed.
3. **`curl -fL` for the framework download** (was `-fL` already); the CLI
   download keeps `-f#L`. `--fail` already made a 404/5xx a hard error; the
   checksum extends that to a *silently corrupted or MITM'd* download — a
   200-with-wrong-bytes that `--fail` can't catch.
4. Renovate (`renovate: datasource=github-releases depName=sparkle-project/Sparkle`
   above `SPARKLE_VERSION`) bumps only the version; the comment on the checksums
   explains that a bump without re-pinning fails the build rather than shipping
   an unverified artifact — which is the desired fail-closed behavior.

## 3. Verification

- [x] Checksums match the 2.9.4 release assets (bytes verified against release asset sizes)
- [x] `shasum -a 256 -c -` passes on the real download
- [x] Tamper test: a deliberately wrong checksum fails the script (verified)

