# Design: Re-check whether disable-library-validation is still needed in Adium.entitlements

- **Issue:** [#254 — Re-check whether disable-library-validation is still needed in Adium.entitlements](../../../../issues/254)
- **Status:** Resolved

## 1. Summary

Found during pre-pr-review of #228 (fastlane release pipeline, #118).

`Adium.entitlements` grants `com.apple.security.cs.disable-library-validation`.
Its original justification (per upstream commit c4c5bb56) was Growl, which is
not currently linked or embedded in the app. `Release/sign-bundle.sh` already
re-signs and team-audits every nested binary, so hardened-runtime library
validation would likely pass without this entitlement now.

Removing an entitlement needs its own verification pass (confirm nothing else
in the vendored dependency set — libpurple, libotr, etc. — needs it) rather
than being bundled into a release-pipeline bug-fix PR. Pre-existing file, not
introduced by #228.

## 2. Approach

**Verdict: keep the entitlement.** `disable-library-validation` is still
required; the original Growl justification is stale, but a newer, load-bearing
one has since replaced it.

Investigation findings:

1. **The app's vendored dylibs are ad-hoc signed.** `Dependencies/build-universal-deps.sh` (and `Dependencies/build-phases/build-common.sh` around the `codesign -s -` path) ad-hoc re-signs the vendored libraries so the signing step in `Release/sign-bundle.sh` can team-audit every nested binary. An ad-hoc signature (`-s -`) carries no team ID.
2. **Hardened runtime + library validation rejects team-less libraries.** With `com.apple.security.cs.allow-jit`-style protections off and the hardened runtime enabled (`-o runtime`, as the release pipeline does), macOS library validation refuses to load any dylib not signed by the app's own team. libpurple, libotr, and the other vendored dylibs are ad-hoc (team-less), so they would fail to load at launch.
3. **The release-pipeline design spec already states this.** `docs/superpowers/specs/2026-08-07-fastlane-release-pipeline-design.md` records that libpurple + the other vendored dylibs need `disable-library-validation` under the hardened runtime. Removing the entitlement would break every launch of the signed, notarized app.

`Adium.entitlements` is a plist and cannot carry comments, so the finding lives here in the design doc instead.

## 3. Verification

- [x] Confirm hardened-runtime library validation rejects ad-hoc (team-less) dylibs without this entitlement — matches design spec + sign-bundle.sh's own team-audit logic
- [x] Keep entitlement unchanged; document finding in design doc (no code change) — done

