# Design: Quote $VERSION before interpolating it into make-dmg.sh's AppleScript heredoc

- **Issue:** [#256 — Quote $VERSION before interpolating it into make-dmg.sh's AppleScript heredoc](../../../../issues/256)
- **Status:** Proposed

## 1. Summary

Found during pre-pr-review of #228 (fastlane release pipeline, #118).

`Release/make-dmg.sh`'s Finder-layout AppleScript is an unquoted heredoc
(`<<APPLESCRIPT`), so `$VERSION` and `$(basename "$APP")` are shell-expanded
directly into the AppleScript source. A `VERSION` containing a `"` or a
backtick could break out of the intended AppleScript string.

Low practical risk: `VERSION` only ever comes from a git tag (character-
restricted by git) or a manual `VERSION=` override run locally by whoever is
cutting the release, against their own machine. Worth quoting/escaping for
defense in depth, but not urgent enough to hold up #228 for.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

