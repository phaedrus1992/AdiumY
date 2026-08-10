# Design: fastlane/Fastfile style cleanups (dedup, naming)

- **Issue:** [#258 — fastlane/Fastfile style cleanups (dedup, naming)](../../../../issues/258)
- **Status:** Proposed

## 1. Summary

Found during pre-pr-review of #228 (fastlane release pipeline, #118). Cosmetic
only — no behavior change in any of these.

- `TEAM_ID` default (`C36L3X7U5T`) is duplicated verbatim in `fastlane/Fastfile`
  and `fastlane/Appfile`; the two files have to change together with nothing
  linking them
- `ENV["X"].to_s.empty? ? fallback : ENV["X"]` appears four times
  (`TEAM_ID`, `ASC_KEY_PATH`, `resolved_version`, `notary_timeout`) — an
  `env_or(name, default)` helper would collapse all four
- `check_notarization_ticket` never returns; every path raises. A name like
  `fail_notarization!` would say so
- `sh("rm", "-rf", ...)` / `sh("cp", "-R", ...)` in the `build` lane could be
  `FileUtils.rm_rf` / `FileUtils.cp_r`
- `signing_identity` is called multiple times per `release` run (each one
  re-running `security find-identity`); could be resolved once and reused

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

