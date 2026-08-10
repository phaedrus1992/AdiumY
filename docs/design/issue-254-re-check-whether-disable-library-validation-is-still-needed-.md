# Design: Re-check whether disable-library-validation is still needed in Adium.entitlements

- **Issue:** [#254 — Re-check whether disable-library-validation is still needed in Adium.entitlements](../../../../issues/254)
- **Status:** Proposed

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

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

