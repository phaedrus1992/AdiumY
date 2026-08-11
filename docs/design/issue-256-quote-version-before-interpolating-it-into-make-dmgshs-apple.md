# Design: Quote $VERSION before interpolating it into make-dmg.sh's AppleScript heredoc

- **Issue:** [#256 — Quote $VERSION before interpolating it into make-dmg.sh's AppleScript heredoc](../../../../issues/256)
- **Status:** Resolved

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

Escape every value that reaches the AppleScript heredoc, instead of trying to
make the heredoc quoted (which would break the shell expansion the script
relies on).

1. **`apple_escape()` helper** in `Release/make-dmg.sh`: collapses newlines to
   spaces (so a multi-line value can't even split the `tell disk` line), then
   escapes backslashes, `"`, and backticks for AppleScript string literals.
   Runs through `tr` + `sed` — no `bash`-isms that would misbehave under the
   `#!/bin/bash` shebang.
2. **Pre-escape both interpolated values** once at the top of the script:
   `ESCAPED_VOLUME_NAME` (from `VOLUME_NAME="AdiumY $VERSION"`) and
   `ESCAPED_APP_LEAF` (from `basename "$APP"`), and use those inside the
   `tell disk "..."` / `set position of item "..."` lines.
3. **Why not quote the heredoc?** An unquoted delimiter is load-bearing here —
   it's the mechanism by which the shell variables reach the AppleScript
   source. Quoting `<<'APPLESCRIPT'` would stop interpolation and the layout
   would silently reference literal `$ESCAPED_VOLUME_NAME`. Escaping the
   *values* is the minimal change that preserves behavior.

## 3. Verification

- [x] `apple_escape` round-trips a benign version (`2.0.0`) unchanged
- [x] `apple_escape` neutralizes hostile inputs (`"`, backtick, newline) — escaped, never dropped
- [x] `shellcheck` clean on the modified script

