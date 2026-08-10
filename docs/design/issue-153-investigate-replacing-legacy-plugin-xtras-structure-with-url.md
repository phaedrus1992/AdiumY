# Design: Investigate replacing legacy plugin/xtras structure with URL schemes + UTIs

- **Issue:** [#153 — Investigate replacing legacy plugin/xtras structure with URL schemes + UTIs](../../../../issues/153)
- **Status:** Proposed

## 1. Summary

## Context
Found during the #122 (AdiumY clean-break rename) audit. The fork has a legacy plugin/xtras system:

- `Resources/Info copy.plist` (legacy, NOT the active plist) declares `CFBundleURLTypes` (`adiumyextra`, `aim`, `xmpp`, `irc`, ...) and `UTExportedTypeDeclarations` (`com.github.phaedrus1992.adiumy.xtra`, `...plugin`)
- The active `Resources/Info.plist` declares none of these (pre-existing gap — URL/UTI registration is currently dead in the app)
- `Source/AIXtrasManager.m:377` builds a `com.adiumx.*` UTI from `CFBundlePackageType` to identify xtra bundles
- `Source/AIAppearancePreferences.m:126-153` classifies dragged items by `com.adiumx.*` UTType identifiers (emoticonset, dockicon, serviceicons, statusicons, menubaricons, contactlisttheme, contactlistlayout)

## Ask
Investigate where modern URL schemes + `UTType`/UTI registration can replace this legacy bundle/package-type mechanism. Specifically:

1. Which legacy xtra/plugin detection paths (`CFBundlePackageType`, `com.adiumx.*` UTI construction, bundle scanning) can be replaced by declared UTIs + `UTType` conformance?
2. Where URL-scheme registration (`adiumyextra://`-style) should live in the active Info.plist vs. dynamic registration — and which schemes are still wanted (`aim`/`xmpp`/`irc` service URLs vs. app-owned schemes)?
3. Tradeoffs: backward compat for existing xtras, Finder type association, drag-and-drop, app-sandbox implications.
4. Migration path + what necessarily stays legacy.

## Deliverable
A written assessment (design doc, e.g. `docs/design/`) with a recommended target structure. No code changes in this issue.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

