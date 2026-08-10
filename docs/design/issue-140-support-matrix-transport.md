# Design: Support: Matrix transport

- **Issue:** [#140 — Support: Matrix transport](../../../../issues/140)
- **Status:** Proposed

## 1. Summary

# Support: Matrix transport

Part of epic #133 (add support + self-contained smoke test).

## Research

- **Original plugin unmaintained:** [purple-matrix](https://github.com/baobabresearch/purple-matrix) declared itself "essentially unmaintained" (2022-04-11). Alpha-level: text messages + joining invited rooms only; no room creation, presence, typing, media, registration, or E2EE. Targets Synapse client-server API r0.0.0.
- **Modern rewrite (2026):** [purple-matrix-rust](https://explore.market.dev/ecosystems/rust/projects/purple-matrix-rust) (created Feb 2026) — a Rust rewrite on the official **matrix-rust-sdk**. Full login (password/SSO/OIDC), room management (create/join/invite/spaces/public search/moderation), rich messaging (HTML/Markdown, media, reactions, typing, read receipts), **E2EE**, threads, session persistence.
- **Server (self-contained test):** **Synapse** — official, actively maintained, Docker image available. This is the best-served transport of the six for self-contained testing.

## Plan

1. **Decide build path** — evaluate vendoring/building purple-matrix-rust (Rust → check how it links against this Xcode/libpurple build; this fork already builds C libpurple, so a Rust prpl needs a cargo build step + static/dylib linkage — confirm feasibility first). Fallback: implement a minimal C prpl against the Matrix client-server API.
2. **Server bootstrap** — Synapse in Docker, ephemeral port, register two throwaway users, one test room.
3. **Smoke test** — scripted: user B joins the room, Adium (user A) writes a marker message, B asserts receipt; reverse direction. E2EE off for the basic harness.
4. **Teardown** — stop Synapse, drop users/room, delete temp profile.

## Out of scope (this iteration)

E2EE round-trip, media, read receipts, spaces/moderation — wire in after the basic message path is green.

## Related

The Matrix→ActivityPub bridge ([matrix-appservice-activitypub](https://github.com/Haven-Organization/matrix-appservice-activitypub)) is a possible cross-link with the ActivityPub issue.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

