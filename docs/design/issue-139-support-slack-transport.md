# Design: Support: Slack transport

- **Issue:** [#139 — Support: Slack transport](../../../../issues/139)
- **Status:** Proposed

## 1. Summary

# Support: Slack transport

Part of epic #133 (add support + self-contained smoke test).

## Research

- **No active libpurple plugin found** — the old `purple-slack` relied on Slack's RTM API, which Slack has deprecated and shut down. Search for a maintained `prpl-slack` in 2026 returns nothing live.
- **Current Slack API:** Web API + Events API / **Socket Mode** (WebSocket). Socket Mode is the modern replacement for RTM and is what a chat client should target.
- **Server (self-contained test):** Slack is proprietary cloud; there is **no self-hostable Slack-API-compatible server** (Mattermost is a different product, not API-compatible). Self-contained testing is therefore the hardest of this set: either (a) a throwaway Slack workspace + test bot app (semi-contained), or (b) a local Socket Mode / Web API **mock** that speaks enough of the protocol for the harness.

## Plan

1. **Decide approach** — implement a minimal prpl against Slack Web API + Socket Mode (there is no maintained plugin to vendor), OR a local mock. Research the Socket Mode handshake + message event shape first.
2. **Server bootstrap** — build the local mock (WebSocket endpoint + Web API stubs) so the smoke test is fully self-contained; document the throwaway-workspace fallback.
3. **Smoke test** — scripted: mock accepts the bot connection, Adium sends a message, mock asserts receipt; mock→Adium direction too.
4. **Teardown** — stop mock, delete temp profile.

## Out of scope (this iteration)

Workspace admin APIs, threads deep-dive, reactions, file uploads, legacy RTM.

## Caveat

Slack ToS limits automation; a test workspace + bot under the harness's own control is fine for CI, but note it needs a real account credential at runtime (bot token) — the one transport here that can't be 100% credential-free.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

