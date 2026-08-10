# Design: Support: RSS/Atom transport

- **Issue:** [#143 — Support: RSS/Atom transport](../../../../issues/143)
- **Status:** Proposed

## 1. Summary

# Support: RSS/Atom transport

Part of epic #133 (add support + self-contained smoke test). **Covers RSS 2.0 and Atom feeds** (also consider JSON Feed).

## Research

- **No libpurple plugin found for RSS/Atom in current libpurple.** (A historical `rss-ng` existed for old Pidgin/GAIM; not in libpurple 2.14 and no maintained successor.) Greenfield.
- **Model fit:** RSS/Atom is the purest case of the user's "subscribe to channels of info" model — a feed is a channel; each entry is an item in a chat/feed view. No reply path needed (or optional: share/boost/post-to-feed).
- **Update mechanism:** polling (HTTP ETag/Last-Modified, cheap) is the baseline; **WebSub** (formerly PubSubHubbub) gives push and is worth supporting. Both are simple HTTP.
- **Server (self-contained test):** trivially self-contained — a local HTTP server serving a set of fixture feeds (RSS 2.0 + Atom). Generating a new entry = the assertion trigger. No heavyweight server.

## Plan

1. **Decide approach** — implement a minimal prpl (or a non-prpl plugin) where each subscribed feed is a contact/channel: fetch (with ETag/Last-Modified), parse RSS 2.0 + Atom (NSXMLParser or a C parser), surface new entries in the message view. Subscriptions stored per-account.
2. **Server bootstrap** — a small local HTTP server (Python `http.server` wrapper or a tiny script) serving fixture feeds on an ephemeral port, with a "publish new entry" endpoint for tests.
3. **Smoke test** — scripted: (a) Adium subscribes to the fixture feed, existing entries appear; (b) test publishes a new entry, Adium's feed view surfaces it (poll interval tuned for the harness, or WebSub push if implemented); (c) malformed feed fixture → graceful error, no crash. Assert all three.
4. **Teardown** — stop fixture server, delete temp profile/subscriptions.

## Out of scope (this iteration)

WebSub push (nice-to-have after polling), feed→MUC bridging, read/unread sync, JSON Feed (can add cheaply).

## Related

RSS subscription shares UI/mechanics with the ActivityPub and atproto subscription models — a shared "channel subscription" abstraction across those three transports is worth designing early (see epic #133 shared requirements).

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

