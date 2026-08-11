# Design: fastlane/Fastfile style cleanups (dedup, naming)

- **Issue:** [#258 — fastlane/Fastfile style cleanups (dedup, naming)](../../../../issues/258)
- **Status:** Resolved

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

All five items, each a no-behavior-change refactor:

1. **TEAM_ID dedup** — new `fastlane/shared.rb` (loaded via `require_relative`
   from both `Fastfile` and `Appfile`) owns `TEAM_ID_DEFAULT = "C36L3X7U5T"`.
   Both files now read it from there, so the default lives in exactly one
   place.
2. **`env_or(name, default)` helper** in `shared.rb` collapses all four
   `ENV["X"].to_s.empty? ? fallback : ENV["X"]` sites: `TEAM_ID`, `ASC_KEY_PATH`,
   `resolved_version`, `notary_timeout`.
3. **`fail_notarization!`** — `check_notarization_ticket` renamed to say what
   it does: never returns, every path raises. `!` marks the always-fatal
   contract; a comment notes it never returns.
4. **`FileUtils`** — the `build` lane's `sh("rm", "-rf", ...)` /
   `sh("cp", "-R", ...)` for MMTabBarView.framework replaced with
   `FileUtils.rm_rf` / `FileUtils.cp_r` (Ruby-native, no shell).
5. **`signing_identity` memoized** — split into a memoizing `signing_identity`
   (`@signing_identity ||= ...`) and a private `compute_signing_identity` that
   does the `security find-identity` work. `return` inside a `||=` block
   doesn't memoize in Ruby, which is why it's a separate method.

## 3. Verification

- [x] `ruby -c` clean on `Fastfile`, `Appfile`, `shared.rb`
- [x] `TEAM_ID` default resolves identically from both files (same constant)
- [x] `signing_identity` memoized — one `security find-identity` per run

