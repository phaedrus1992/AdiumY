# Design: General code audit: refactor, cleanup, and de-duplication opportunities

- **Issue:** [#162 — General code audit: refactor, cleanup, and de-duplication opportunities](../../../../issues/162)
- **Status:** Proposed

## 1. Summary

## Summary

General code audit of the AdiumY codebase to find opportunities to refactor, clean up, de-duplicate, and improve overall code quality. This is a discovery issue: the goal is to catalogue concrete, actionable improvements — not to implement them all in one PR.

## Scope

Walk the codebase (with an eye toward the areas below) and file follow-up issues for each concrete finding, or fix trivial ones directly if they're small and low-risk.

- **Dead code** — unused classes, methods, macros, constants, and resources (e.g. the latent Adium 1.4 one-time pref migration in `AIWebKitMessageViewPlugin.m`, legacy `hg` references, build-time leftovers).
- **De-duplication** — repeated logic that should be shared (the bundle-ID prefix work in #157 is one example; find others: repeated Xtra type handling, repeated dispatch-queue creation, repeated preference-registration patterns).
- **Modernization** — APIs replaced by newer Foundation/AppKit equivalents, old syntax patterns (manual `autorelease` remnants, deprecated APIs, `NSDictionary` literal opportunities).
- **Consistency** — naming, formatting, error handling, and conventions that diverge from the project's own style (see CLAUDE.md).
- **Correctness risks** — silent failure paths, ignored return values, potential retain cycles, thread-safety gaps in shared singletons.
- **Testability** — hot spots with no coverage that property-based or edge-case tests would meaningfully protect.

## Out of scope

- New features and behavior changes (file those separately).
- Network protocol work and libpurple integration.

## Approach

1. Audit each area in this issue's scope.
2. For each finding, either file a follow-up issue (milestone `v2.1.0`, label `cleanup`/`modernization`) or note it in a comment here if too small to file.
3. Summarize findings as a checklist in this issue so it can be tracked to completion.

## Acceptance criteria

- [ ] Codebase surveyed across all scope areas
- [ ] Follow-up issues filed (or noted as trivial/inline) for every non-trivial finding
- [ ] Summary of findings posted to this issue

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

