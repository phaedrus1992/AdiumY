# Design: Adium target + UI plugins ARC migration and global cleanup

- **Issue:** [#38 — Adium target + global cleanup: migrate to ARC](../../../../issues/38)
- **Status:** Proposed
- **Governing spec:** `docs/superpowers/specs/2026-07-08-libpurple-upgrade-arc-design.md` (Phase 2, steps 3–4 + wrap-up). The conversion playbook (idiom table, hazards, mechanics) lives in `issue-37-adium-framework-arc.md` §2 — this doc does not repeat it.
- **Depends on:** #37 (Adium.framework ARC) merged.
- **Scope:** `Source/` (246 `.m`), `Plugins/` except Purple Service (≈122 `.m` total in Plugins; Purple Service is excluded), the app-target xcconfig, then a global sweep

## 1. Dependency correction

The issue body's "Depends on: AdiumLibpurple ARC (Issue #6), Adium.Framework
ARC (Issue #7)" uses stale numbering **and stale ordering**. Per the spec,
Purple Service/AdiumLibpurple converts *last* (step 5) because of its C
callback surface — it is **not** a prerequisite for this issue. Actual
prerequisites: AIUtilities (done) and Adium.framework (#37).

This issue is "final target" only for the app-and-UI layer; the true final
step is the Purple Service/AdiumLibpurple conversion (issue #36 — closed but
its work was reverted in `6ded91c0`; see the housekeeping note in #37's doc).

## 2. Plan

Two conversion commits + one cleanup commit, each building and launching
(spec: one commit per target):

### 2.1 Commit 1 — `Source/` (the Adium app target)

Flip `CLANG_ENABLE_OBJC_ARC = YES` for the app target (add to
`xcconfigs/Adium.xcconfig` — verify that file drives only the app target
before flipping; if it's shared, use target-level build settings instead).
Apply the #37 playbook. Target-specific hazards on top of it:

- `Source/AIAdium.m` and controller singletons: heavy
  NSNotificationCenter/KVO teardown in deallocs — keep those deallocs.
- Window/sheet controllers using `(void *)contextInfo` sheet APIs: every
  `beginSheet…contextInfo:` crossing needs an audited `__bridge` pair
  (search: `contextInfo:`).
- `performSelector:withObject:afterDelay:` retain semantics differ subtly
  under ARC only for the selector-not-known warnings; silence by refactoring
  to blocks **only** where the compiler actually warns.

### 2.2 Commit 2 — UI plugins (all `Plugins/` targets except Purple Service)

Same treatment per plugin target. Note some Purple-adjacent files were
already half-converted during the reverted attempt (`59799821`,
`4991864b` touched `Plugins/Purple Service/`) — those are Purple Service and
stay out of scope here. The WebKit Message View plugin is the biggest single
plugin; its DOM/WebView object graph is strongly-referenced from JS-facing
wrappers — check for delegate cycles after conversion with the Instruments
pass rather than by eyeball.

### 2.3 Commit 3 — global cleanup (the "+ global cleanup" half of the issue)

Once every first-party target except Purple Service/AdiumLibpurple is ARC:

- Remove MRR-era scaffolding that no longer has a reader:
  `rg -n "NSAutoreleasePool|\\[super dealloc\\]|-fno-objc-arc"` across
  first-party code → should return only Purple Service hits (documented) and
  justified exceptions.
- Delete any `#if !__has_feature(objc_arc)` compatibility shims that are now
  dead on the ARC side.
- Ensure no first-party xcconfig still sets `CLANG_ENABLE_OBJC_ARC = NO`
  except `AdiumLibpurple.xcconfig` (pending its own issue) — and that one
  keeps its explanatory comment.
- Update `docs/superpowers/specs/2026-07-08-libpurple-upgrade-arc-design.md`
  status notes (or the tracking issue) so Phase 2 progress is recorded where
  the next person will look.

## 3. Verification

Per commit: full clean build zero-warning, unit tests green, launch smoke
(connect account, open chat, transfer a file, open prefs panes — prefs are
`Source/`-heavy, exercise several).

End state: Instruments Leaks + Zombies over the smoke flow; no zombies, no
new leaks vs. a pre-conversion baseline run (record the baseline first —
Adium has pre-existing leaks; the gate is *no regressions*, and any
pre-existing leak worth fixing gets an issue, not a silent pass).

## 4. Out of scope

- Purple Service + AdiumLibpurple ARC (spec step 5; reopen #36 or file fresh).
- MMTabBarView and other third-party/submodule code (spec exclusion).
- ObjC modernization beyond ARC's requirements.
