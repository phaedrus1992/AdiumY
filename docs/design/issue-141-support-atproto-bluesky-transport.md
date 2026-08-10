# Design: Support: atproto (Bluesky) transport

- **Issue:** [#141 — Support: atproto (Bluesky) transport](../../../../issues/141)
- **Status:** Proposed

## 1. Summary

# Support: atproto (Bluesky) transport

Part of epic #133 (add support + self-contained smoke test).

## Research

- **No libpurple plugin found** for Bluesky/ATProto — greenfield.
- **Protocol:** AT Protocol (`atproto`) is open and federated; Bluesky is the flagship network. Client access is via XRPC (HTTP JSON) + the streaming WebSocket firehose. Two consumption models fit Adium:
  - **IM/DMs:** `chat.bsky.convo` namespace (Bluesky's private DM feature).
  - **Subscription + replies:** follow public feeds/timelines (home feed, list feeds, search) as "channels of info" that stream new posts; **replies are supported** — a post in a followed channel can be replied to, and the reply posts to the conversation/feed. This matches the user's note that a transport need not be strict IM.
- **Server (self-contained test):** ATProto personal data servers (PDS) are self-hostable. A local PDS gives a fully self-contained harness for both models.

## Plan

1. **Feasibility research** — confirm (a) DM API surface (`chat.bsky.convo.*`) for a non-official client, (b) whether a local PDS (go-atproto / Bluesky PDS repo) supports DMs, feed streaming, **and replying** between two local accounts, (c) auth (app password) model.
2. **Decide approach** — implement a minimal prpl: XRPC for identity + DM send/receive, plus a **subscription mode** where followed feeds appear as contact-like "channels" that surface new posts, with **reply support** (reply→post, replies-in-thread surfaced). Polling is a fine first cut; WebSocket firehose for live updates later.
3. **Server bootstrap** — local PDS on an ephemeral port, two throwaway accounts, a test feed.
4. **Smoke test** — scripted: (a) IM — B DMs A, Adium receives and replies; (b) subscription+reply — A follows a feed, a new post appears in Adium's channel view, A replies, B sees the reply. Assert both.
5. **Teardown** — stop PDS, drop accounts, delete temp profile.

## Out of scope (this iteration)

Rich embeds, media, list-feed curation, firehose backfill, likes/boosts/reposts.

## Caveat

If a local PDS can't do DMs or streaming yet, record that finding and use a throwaway dev account on the public network (semi-contained), or park the transport.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

