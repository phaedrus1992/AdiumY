# Design: Raise test coverage to 90%

- **Issue:** [#77 — Raise code test coverage to 90%](../../../../issues/77)
- **Status:** Proposed
- **Scope:** all first-party targets; `scripts/coverage-check.sh`; CI. This is a long-running program, not one PR — the design here is the ratchet machinery plus the per-file working method.

## 1. Starting point

- #76 (closed) delivered the machinery: `make coverage-check` →
  `scripts/coverage-check.sh`, threshold via `COVERAGE_THRESHOLD` (default 50),
  xccov-based, wired into CI (`.github/workflows/ci.yml:129-139`).
- Existing tests: `UnitTests/` (25 files — mostly AIUtilities-style
  additions/categories tests) and `ASUnitTests/`, built by the "Unit tests"
  target (`make test`).
- Production surface: `Frameworks/Adium/Source` 105 `.m`, `Source/` 246 `.m`,
  `Plugins/` 122 `.m`, plus AIUtilities. 90% line+branch across that is a
  large multi-month program; the design must make progress monotonic and
  cheap to resume.

## 2. Design

### 2.1 Ratchet, don't leap

Extend `scripts/coverage-check.sh` to support **per-target thresholds** read
from a checked-in file (`scripts/coverage-thresholds.txt`, `target percent`
per line; targets absent fall back to `COVERAGE_THRESHOLD`). Rules:

- A PR that raises a target's measured coverage may (should) raise that
  target's threshold to `floor(measured)`.
- CI fails if any target drops below its threshold — this is the issue's
  "never regress" requirement made mechanical instead of reviewer-enforced.
- Endgame: every first-party target's line reads ≥90.

This is deliberately dumb (no history, no diff-coverage tooling): the
threshold file *is* the progress tracker and survives any CI provider.

### 2.2 Priority order (from the issue, with reasoning attached)

1. **Adium.framework, AIUtilities** — pure-ish logic, testable today, highest
   value per test (everything depends on them).
2. **AdiumLibpurple / Purple Service** — the stanza/glue logic (and every XEP
   design doc in `docs/design/issue-2x-*.md` mandates headless xmlnode tests,
   so new code arrives tested; only backfill is old code).
3. **`Source/` (app layer)** — biggest and hardest; controllers first
   (logic), window controllers last (see 2.4).
4. **Forked frameworks** — only Adium-side additions; vendored code excluded.
5. **Scripts** — `scripts/*.sh` get bats or plain assert-style shell tests;
   Python utilities get pytest (there is little Python left after #70).

Maintain exclusions (vendored/third-party code) **in the coverage script**,
not in reviewers' heads: xccov reports per-target; forked-framework targets
get thresholds covering only Adium-owned files if xccov granularity allows,
else document the carve-out in the thresholds file as a comment.

### 2.3 The per-file working method (the loop a contributor runs)

1. `make test` with coverage on; `xcrun xccov view --report <xcresult>`
   sorted ascending within the current priority target.
2. Take the worst-covered file **that contains logic** (skip pure-UI glue
   until phase 3). Read it; identify public behavior and edges (empty,
   boundary, malformed, error paths).
3. Write XCTest cases against behavior, not internals. Mock only at I/O
   boundaries (network, filesystem, Apple frameworks) — OCMock or hand-rolled
   fakes; never mock Adium-internal classes into meaninglessness.
4. **Mutation check (required by the issue):** break the code under test
   (invert a condition), confirm the new test fails, revert. Note it in the
   PR ("mutation-verified").
5. Raise the target's threshold line. One PR per coherent cluster of files.

### 2.4 The honest hard part: testability of the app layer

Much of `Source/` reaches through `adium.<controller>` singletons and can't
instantiate under XCTest. Standing rule for this program:

- **Do not** launch a whole-app harness to juice numbers.
- **Do** extract logic out of window controllers into plain objects when a
  file resists testing (smallest extraction that decouples, no speculative
  protocol layers).
- Some strictly-UI files (nib-loading glue) may never reach 90 individually;
  the target-level number absorbs them. If a target provably cannot reach 90
  without harness theater, stop at its honest maximum, record the number and
  reason in the thresholds file, and say so on this issue — a defended 84%
  beats a gamed 90%.

### 2.5 Branch coverage

`xccov` reports line coverage only. The issue says line+branch; get branch
data via `llvm-cov export -summary-only` over the same profdata (the script
already locates profdata), and gate on line coverage while *reporting* branch
coverage per target. Promote branch numbers into the gate only once line ≥90
lands — one ratchet at a time.

## 3. Verification (of the machinery PR — the first PR of this program)

- Thresholds file honored: set one target's line above its measured value in
  a scratch branch → CI fails; at measured value → passes.
- `COVERAGE_THRESHOLD` fallback still works for unlisted targets.
- Coverage report artifact uploaded by CI so progress is visible without a
  local run.

## 4. Out of scope

- Swift, performance/integration tests, vendored-framework coverage (issue's
  own exclusions).
- Diff-coverage services (Codecov etc.) — revisit only if the thresholds
  file becomes painful.
- Mutation-testing *tooling* (mutanus etc.): the manual mutation check in
  2.3 is the requirement; automating it is a possible follow-up issue.
