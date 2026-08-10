# Design: Add test coverage for fastlane/Fastfile's parsing/normalization logic

- **Issue:** [#257 — Add test coverage for fastlane/Fastfile's parsing/normalization logic](../../../../issues/257)
- **Status:** Proposed

## 1. Summary

Found during pre-pr-review of #228 (fastlane release pipeline, #118).

`fastlane/Fastfile` has no test coverage at all — it's Ruby, and this repo's
test infrastructure is entirely Objective-C/XCTest (`UnitTests/`). Several
functions have parsing/normalization logic worth covering:

- `signing_identity` / `resolve_identity_override` — regex parsing of
  `security find-identity` output, now also resolving a SHA-1 to its full
  quoted name (fixed in #228, but the parsing itself is untested)
- `resolved_version` — strips a "v" prefix from either a git tag or `VERSION=`
- `requested_submission_id` — case-insensitive lane-option lookup
- `notarytool_json` / `latest_accepted_submission` / `artifact_for_submission`
  — JSON parsing and routing logic around notarization submissions

Adding RSpec (or similar) is new test infrastructure for this repo, so it's
being deferred as its own scoped piece of work rather than bundled into a
release-pipeline bug-fix PR.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

