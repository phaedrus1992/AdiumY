# Design: Rename user-visible product name to "AdiumY"

- **Issue:** [#2 — Rename Project to AdiumY](../../../../issues/2)
- **Status:** Proposed
- **Scope:** app-target build settings/Info.plist, `Resources/MainMenu.xib`, `Resources/en.lproj/Localizable.strings` (+ InfoPlist.strings), README/CHANGELOG. Explicitly **not** class prefixes, file names, or on-disk data paths.

## 1. Problem

The fork should present itself as "AdiumY" everywhere a user can see the name.
Internal identifiers are already forked (bundle ids are
`com.github.phaedrus1992.adiumY.*` throughout `project.pbxproj`), but every
visible surface still says "Adium": menu bar app menu, About box, Dock, Finder,
menu items ("About Adium", "Quit Adium"…), assorted UI strings, README.

## 2. Boundaries — what must NOT change

These are load-bearing; renaming them breaks user data or working code:

1. **Application Support path.** `Frameworks/Adium/Source/AIPathUtilities.m`
   defines `ADIUM_APP_SUPPORT` → `~/Library/Application Support/Adium 2.0`,
   and `Source/AIAdium.m` builds the same path. Existing users' accounts,
   logs, and prefs live there. Keep it. (A migration is a separate project;
   don't smuggle it into a rename.)
2. **Bundle identifiers** — already forked; leave as-is (changing them again
   orphans saved preferences under those domains).
3. **Class names, `AI*`/`ES*`/`CB*` prefixes, source file names, framework
   names** (`Adium.framework` etc.) — internal, invisible to users, and a
   mass-rename would poison every future diff against
   `mark-final-upstream`.
4. **URLs pointing at github.com/phaedrus1992/adiumy infrastructure** — they name a service, not
   this product. Out of scope (mostly dead anyway; other issues handle them).
5. **Localized `.lproj` translations other than English** — the fork does not
   maintain translations; renaming inside `de.lproj` et al. is churn with no
   reviewer. English only.

## 3. Design

### 3.1 Bundle naming (Dock, Finder, menu bar)

In the Adium app target (`Adium.xcodeproj`, target "Adium",
`PRODUCT_NAME = "${TARGET_NAME}"` around `project.pbxproj:9588`):

- Set `PRODUCT_NAME = AdiumY` on the app target only (all three
  configurations). This renames `Adium.app` → `AdiumY.app` and, since
  `Resources/Info.plist` uses `$(PRODUCT_NAME)` for `CFBundleName`, fixes
  Dock/Finder/menu-bar in one move.
- Grep `project.pbxproj` and any xcconfigs for hardcoded `Adium.app` paths in
  copy/script phases and `Release/`+`Makefile` packaging; update matches.
- Do **not** touch `PRODUCT_NAME = Adium` on the framework targets
  (`project.pbxproj:9424/9440/9456`) — `Adium.framework` is internal (see §2.3).

### 3.2 Menus and strings

- `Resources/MainMenu.xib` — 5 literal `"Adium…"` strings (About Adium, Hide
  Adium, Quit Adium, the app menu title, etc.). Replace with AdiumY.
- `Resources/en.lproj/Localizable.strings` — replace "Adium" **only in
  user-facing values**, reviewed by hand, not blind sed: skip anything that is
  a path, a URL, or a key rather than a display value. Same pass over
  `en.lproj` nib `.strings` files that mention the product name
  (`rg -l '"[^"]*Adium' Resources/en.lproj`).
- Code-embedded display strings: `rg -n '@"[^"]*Adium[^"]*"' Source Plugins
  Frameworks/Adium` and triage — only strings shown in UI (window titles,
  alert text, menu items built in code) change. When a string is built near a
  bundle lookup, prefer substituting
  `[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]` over a
  second hardcoded name **only when the surrounding code already does dynamic
  formatting**; otherwise a plain literal edit is fine. No new helper API.

### 3.3 Documentation

- `README.md` (16 mentions): retitle to AdiumY, keep the "fork of Adium"
  provenance sentence — the doc should say AdiumY *is a fork of* Adium, not
  scrub history.
- `CHANGELOG.md`: add an entry; do not rewrite old entries.
- `AdiumHelp/` help book: out of scope for v1 (large, low-traffic, and the
  help book may be dropped entirely someday). Note it in the PR as known-
  remaining.

### 3.4 Internal-identifier audit

The bundle-id fork (`com.github.phaedrus1992.adiumY.*`) predates this work and
may have missed spots. Audit — don't assume:

- `rg -n 'com\.adiumX|com\.adium\b|im\.adium' Adium.xcodeproj Plists Resources
  Source Plugins Frameworks --iglob '!*.lproj'` — every hit is either migrated
  to the `adiumY` prefix or justified in the PR (e.g. reading a *legacy*
  defaults domain on purpose).
- Note from the initial recon: the app target's bundle id is
  `com.github.phaedrus1992.adiumY.adiumX` (`project.pbxproj:9482`) — the
  `adiumX` leaf looks like a leftover; confirm intent and normalize (likely
  `…adiumY.Adium` or just the app id without a stale leaf). Changing it
  orphans any prefs already saved under it, so if this fork has real users,
  keep it and document; if it's pre-release, fix it now while it's cheap.
- Check the non-pbxproj identifier carriers: `Adium.entitlements`
  (app-group/keychain-access-group strings), `Plists/*.plist` plugin bundle
  ids, URL scheme declarations (`adiumxtra://`, `x-adium:`… — search
  `CFBundleURLTypes`), UTI declarations (`UTExportedTypeDeclarations` in the
  legacy `Resources/Info copy.plist` — port whatever is still wanted to the
  active plist under adiumY identifiers), and `CFBundleHelpBookName`.
- Defaults domains follow the bundle id automatically; list any code that
  names a defaults domain explicitly (`rg 'persistentDomainForName|initWithSuiteName'`).

Deliverable: a short table in the PR description — identifier, location,
kept/changed, why.

### 3.5 Suggested execution order (one PR, reviewable commits)

1. Internal-identifier audit (findings may adjust the steps below).
2. `PRODUCT_NAME` + packaging-path fixes (build must produce runnable
   `AdiumY.app`).
3. MainMenu.xib.
4. en.lproj strings pass.
5. Code-literal pass.
6. README/CHANGELOG.

## 4. Verification

- Build & launch: Dock shows AdiumY, app menu says AdiumY, "About AdiumY"
  shows the right name, Quit menu item correct.
- Existing-data check (the critical one): run the new build in a user account
  that already has `~/Library/Application Support/Adium 2.0` with an account
  configured — accounts, logs, and prefs must all appear untouched.
- `rg -n '"Adium ' Resources/en.lproj Resources/MainMenu.xib` — remaining hits
  are all justified (paths/URLs/provenance), listed in the PR description.

## 5. Out of scope

- Help book (`AdiumHelp/`), non-English lproj, class/file/framework renames,
  bundle-id changes, Application Support migration, github.com/phaedrus1992/adiumy URL replacement.
