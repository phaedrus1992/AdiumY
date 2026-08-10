# Design: Document version-based milestone management + add forward-merge/release automation to agent rules

- **Issue:** [#156 — Document version-based milestone management + add forward-merge/release automation to agent rules](../../../../issues/156)
- **Status:** Proposed

## 1. Summary

AdiumY has no release branches yet (only `mark-final-upstream` tag). The agent rules (project CLAUDE.md + the dev-sprint / nbl-dev:ship-issue skills that drive milestone→branch resolution) assume a branch layout that does not yet exist and is not documented. This issue codifies the scheme so the rules and CI match it.

## The version-branch scheme to document

- **Until v2.0.0 releases:** all development happens on `main`.
- **After v2.0.0:** cut a `release/2.x` branch; versioned milestones map mechanically:
  - `v2.1.0` (next-minor/patch line) → `release/2.x`
  - `v3.0.0` (next-major) → `main`
- Milestones are the source of truth for the base branch (`resolve-base-branch.sh` in dev-sprint already implements milestone → `release/N.x` fallback-to-default; make it match this documented scheme).

## Agent rules update (CLAUDE.md + skill rules)

- Document the above milestone→branch mapping in the project CLAUDE.md so future runs (and the resolver) know when to branch from `release/2.x` vs `main`.
- Note the forward-merge expectation: fixes merged to `release/2.x` get forward-merged to `main` automatically (see CI below); `main` is never merged down.

## Forward-merge + release automation (copy from llmenv and servarr-operator)

Use these as working guides — both already implement the cascade:

- `llmenv` `.github/workflows/forward-merge-release.yml` — cascades `release/*.x` → newer → `main` on push, with a `forward-merge-conflict` label + PR for unresolvable conflicts.
- `servarr-operator` `.github/workflows/forward-merge-release.yml` and `close-issues-release-merge.yaml` — same cascade plus auto-closing milestone issues on release merge.

Work items:

1. Copy the forward-merge workflow(s) into `.github/workflows/`, adapted to the AdiumY release naming, pinned to commit SHA + version comment (repo convention).
2. Copy the auto-close-issues-on-release workflow so milestone-complete issues close when a `release/2.x` version ships.
3. Add changelog management: Keep-a-Changelog discipline is already in place; tie it to releases (cut a real `## [x.y.z]` section at tag time, update version footer links, keep `[Unreleased]` on top). Optionally a release-drafter/release-notes step in `release.yml`.

## Acceptance

- Project CLAUDE.md documents the milestone→branch scheme (pre- and post-v2.0.0).
- `.github/workflows/` has forward-merge (release/2.x → main) + release auto-close actions copied from llmenv/servarr-operator, SHA-pinned.
- A dry-run of the cascade is verified once `release/2.x` is first cut after v2.0.0.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

