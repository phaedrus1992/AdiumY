# Design: AdiumLibpurple / Purple Service ARC migration (second attempt)

- **Issue:** [#36 — AdiumLibpurple: migrate to ARC](../../../../issues/36) (reopened — the first attempt, PR #41, was merged and then reverted in `6ded91c0`)
- **Status:** Proposed
- **Governing spec:** `docs/superpowers/specs/2026-07-08-libpurple-upgrade-arc-design.md` (Phase 2, step **5 — last target**). The conversion playbook lives in `issue-37-adium-framework-arc.md` §2; this doc covers only what is different here, which is everything that made attempt #1 fail.
- **Depends on:** #37 (Adium.framework ARC) and #38 (app + UI plugins ARC) merged. The issue body's original "Depends on: Nothing (first target)" ordering is obsolete — the spec deliberately moved this target to the end because of its C-callback surface.
- **Scope:** the AdiumLibpurple target — `Plugins/Purple Service/` ObjC sources (~55 files incl. `CBPurpleAccount.m` at 108K and the `adiumPurple*.m` UI-ops bridges), `Frameworks/AIUtilities/xcconfigs/AdiumLibpurple.xcconfig`. libpurple itself is C — unaffected.

## 1. Post-mortem of attempt #1 (PR #41 → revert `6ded91c0`)

Current state: `AdiumLibpurple.xcconfig:20` pins `CLANG_ENABLE_OBJC_ARC = NO`
with the comment "code needs brace fixes and manual-retain". Reading the
revert diff, the attempt had the right vocabulary but three failure modes:

1. **Unbalanced bridge transfers.** e.g. `adiumPurpleFt.m`'s destroy callback
   gained `CFBridgingRelease(xfer->ui_data)` without the corresponding
   `CFBridgingRetain` where `ui_data` is *assigned*. A release without its
   paired retain is an over-release crash on the first file transfer. The
   lesson: bridge annotations must be introduced **per ownership pair (store
   site + free site together)**, never per file.
2. **Mechanical block insertion.** `@autoreleasepool {` wrappers were added
   without re-indenting or verifying brace matching across 55 files in one
   pass ("brace fixes" in the xcconfig comment). One-shot mass edits at this
   scale can't be reviewed; the diff hid the real semantic changes (#1)
   inside thousands of whitespace lines.
3. **Bundled with API-delta work.** The same series carried libpurple-2.14
   API fixes, so every crash was ambiguous between memory management and API
   change (this is now spec doctrine: Phase 1 MRR, Phase 2 ARC).

Attempt #2 exists to invert those three: pair-wise ownership audit first,
small reviewable commits, nothing but ARC in the series.

## 2. Design

### 2.1 Step 1 — ownership inventory (the actual work; do this before any edit)

Catalogue every ObjC-object crossing into C-land. Search surface (counts as
of this writing, `grep -c "ui_data\|PURPLE_CALLBACK"`):
`SLPurpleCocoaAdapter.m` (26), `adiumPurpleSignals.m` (19),
`adiumPurpleFt.m`, `adiumPurpleConversation.m`, `adiumPurpleBlist.m`,
`CBPurpleAccount.m`, `adiumPurpleRequest.m`, `adiumPurpleCore.m`,
`AMXMLConsoleController.m`, `AMPurpleJabberNode.m`, plus every
`purple_timeout_add` / `g_idle_add` / `->ui_data` / `user_data` hit.

For each crossing, record in a scratch table (goes in the PR description):
**what object, where stored, who owns it, where freed.** Then classify:

- **(a) Unretained reference, Adium owns elsewhere** — e.g. account objects
  reachable via `accountLookup(...)`: plain `__bridge` cast both ways, no
  transfer. This should be the majority.
- **(b) The C side holds the only reference** — e.g. `ESFileTransfer` in
  `xfer->ui_data` if nothing ObjC-side retains it for the transfer's
  lifetime: `(void *)CFBridgingRetain(obj)` at the store site,
  `CFBridgingRelease(...)` at exactly one teardown site (the purple
  destroy/free callback), `__bridge` for all intermediate reads. Verify
  what actually owns each case by reading, not guessing — under MRR some of
  these were retained on the ObjC side and merely *referenced* from
  `ui_data`, which is class (a).
- **(c) Callback context for one-shot callbacks** (request dialogs, timers):
  `CFBridgingRetain` at scheduling, `CFBridgingRelease` in the callback —
  and audit the cancellation path (purple request *close* without fire) for
  the leak/double-release twin.

### 2.2 Step 2 — pre-ARC mechanical cleanup (separate PR, still MRR)

Everything ARC will force that can land while the target still builds MRR,
so the eventual flag-flip diff contains only semantics:

- `NSAutoreleasePool` → `@autoreleasepool` (compiles fine under MRR),
  with correct indentation this time.
- Fix anything from the "brace fixes" bucket the last attempt hit.
- This PR is behavior-neutral and easy to review; it also re-tests the
  glib-main-loop autorelease assumption (every C callback entry point needs
  a pool — the existing code already knows which those are).

### 2.3 Step 3 — flip and convert, in slices

Flip `CLANG_ENABLE_OBJC_ARC = YES` in `AdiumLibpurple.xcconfig` (restore
`-Wno-arc-performSelector-leaks` only if the warnings are genuinely the
dynamic-selector false positive — check each first). Then fix errors in
review-sized commits grouped by ownership cluster, applying the step-1 table:

1. Pure-ObjC files (AMPurpleJabber*, view controllers) — playbook from #37,
   no bridges.
2. One `adiumPurple*.m` bridge file per commit, each carrying its store-site
   + free-site pairs *together* (the anti-pattern-1 rule).
3. `SLPurpleCocoaAdapter.m` and `CBPurpleAccount.m` last — biggest, most
   crossings.

Spec rules apply: zero warnings; no `-fno-objc-arc` file exceptions unless
justified inline; final squash to commits that each build and launch.

## 3. Verification

- Build both architectures; existing unit tests green.
- Smoke per the spec: XMPP + IRC accounts connect over TLS, OTR session
  establishes — plus the crossings this target owns: **file transfer
  send/receive/cancel-both-sides** (exercises the exact `ui_data` pair that
  crashed attempt #1), buddy-list updates, a request dialog (auth prompt)
  both confirmed and dismissed, cert-trust alert.
- Instruments Leaks + Zombies over that flow (spec requires it for this
  target specifically). Zombies catches over-release; Leaks catches the
  missing-`CFBridgingRelease` twin. Both must run before merge, not after.
- The ownership table from §2.1 ships in the PR description so review can
  check pairs mechanically.

## 4. Out of scope

- libpurple C code, `libpurple_extensions/*.c` (C files, no ARC dimension).
- API modernization, dead-service cleanup, or anything from Phase 1 of the
  spec — this series is ARC only (post-mortem lesson #3).
- MMTabBarView / third-party code (spec exclusion).
