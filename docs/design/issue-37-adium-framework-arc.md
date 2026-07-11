# Design: Adium.framework ARC migration

- **Issue:** [#37 — Adium.Framework: migrate to ARC](../../../../issues/37)
- **Status:** Proposed
- **Governing spec:** `docs/superpowers/specs/2026-07-08-libpurple-upgrade-arc-design.md` (Phase 2, step 2). Read it first; this doc is the per-target execution plan.
- **Scope:** `Frameworks/Adium/Source/` (105 `.m` files), `Frameworks/AIUtilities/xcconfigs/Adium.framework.xcconfig`

## 1. Dependency correction (read before starting)

The issue body says this depends on "AdiumLibpurple ARC (Issue #6)". That is
**stale**. The approved spec reverses the order: ARC lands leaf-first —
1. AIUtilities (**done**: `AIUtilities.framework.xcconfig:8` has
`CLANG_ENABLE_OBJC_ARC = YES`), 2. **Adium framework (this issue)**,
3. Source/Adium.app, 4. UI plugins, 5. Purple Service/AdiumLibpurple last.

Housekeeping fact the implementer should surface, not fix silently: issue #36
(AdiumLibpurple ARC) is closed as completed, but commit `6ded91c0` reverted
that migration and `AdiumLibpurple.xcconfig:20` currently pins
`CLANG_ENABLE_OBJC_ARC = NO`. #36 should be reopened or a fresh issue filed
for spec step 5 — comment on it when starting this work so the tracking is
honest. It does **not** block this issue.

## 2. Approach

Per the spec's mechanics, one target, one commit, builds and launches:

1. Set `CLANG_ENABLE_OBJC_ARC = YES` in
   `Frameworks/AIUtilities/xcconfigs/Adium.framework.xcconfig` (this xcconfig
   drives the Adium.framework target via the repo's `xcconfigs` symlink).
2. Fix every resulting error and warning. Zero warnings is the bar.
3. No `-fno-objc-arc` per-file exceptions unless justified with an inline
   comment (spec rule). Expect none in this target — it is plain ObjC with
   far fewer C-callback crossings than libpurple.

### 2.1 Mechanical conversion patterns

Apply per file; these cover ~95% of the diff:

| MRR idiom | ARC replacement |
|---|---|
| `[x retain]` / `[x release]` / `[x autorelease]` | delete the call (keep the expression's value use) |
| `[super dealloc]` at end of `-dealloc` | delete; keep `-dealloc` only if it still does non-release work (invalidate timers, remove observers), else delete the whole method |
| `NSAutoreleasePool` alloc/drain | `@autoreleasepool { … }` |
| `@property (retain)` | `(strong)` |
| `@property (assign)` on object types | `(weak)` for delegates/back-references; `(strong)` if it was assign-only-by-laziness — judge by ownership, not text |
| explicit ivar + property + synthesize triples | leave structure as-is; this is an ARC pass, not a modernization pass |
| CF↔ObjC casts | `__bridge` (no transfer), `CFBridgingRelease` (CF→ObjC +1), `CFBridgingRetain` (ObjC→CF +1) |
| `(void *)` context params (`performSelector` contexts, KVO contexts, sheet contexts) | `(__bridge void *)` and matching `(__bridge id)` at the receiving end — audit each pair by hand |

### 2.2 Hazards specific to this target

- **Delegates/datasources stored as retained ivars:** converting to `weak`
  changes deallocation timing. When unsure, `unsafe_unretained` matches old
  behavior exactly — prefer `weak` only where nil-on-dealloc is safe.
- **KVO/NSNotificationCenter observers removed in dealloc:** those deallocs
  must stay (minus the `[super dealloc]`). Deleting a whole dealloc that
  still unregisters observers is the classic ARC-conversion crash. Check
  every dealloc before deleting it.
- **`AIListContact` / controller classes with parent/child object graphs:**
  retain cycles that MRR "handled" by leaking or by manual teardown become
  real leaks under ARC. Don't chase them in this PR beyond obvious
  delegate-should-be-weak cases; Instruments pass at the end catches the rest.
- The framework's unit tests (`UnitTests/`, `ASUnitTests/` — check which
  cover framework classes) must pass before and after.

### 2.3 Suggested mechanics

Convert with the compiler, not with regex: flip the flag, then fix errors
file-by-file in dependency-agnostic alphabetical order, committing locally as
checkpoints, squash to one buildable commit at the end (spec: one commit per
target). Xcode's Edit ▸ Convert ▸ To Objective-C ARC can do the bulk edit,
but review its delegate-property decisions manually — it guesses `weak`
aggressively.

## 3. Verification

- Full build of the Adium.framework target and the app: zero errors, zero
  new warnings.
- Existing unit tests green.
- App launches, connects an account, opens a chat, quits cleanly.
- Instruments (Leaks + Zombies) over that smoke flow shows no new leaks
  attributable to framework classes and no zombie hits (spec requires the
  leaks/zombies pass per ARC'd target).

## 4. Out of scope

- `Source/`, `Plugins/`, Purple Service, AdiumLibpurple (issues #38 and the
  reopened #36).
- Modernization (properties, nullability, generics) beyond what ARC forces.
- Fixing pre-existing retain cycles that ARC merely makes visible — file
  issues for any found.
