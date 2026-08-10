# Design: Support: ActivityPub transport

- **Issue:** [#142 — Support: ActivityPub transport](../../../../issues/142)
- **Status:** Proposed

## 1. Summary

# Support: ActivityPub transport

Part of epic #133 (add support + self-contained smoke test).

## Research

- **No libpurple plugin found.** The ecosystem connects IM to ActivityPub via bridges rather than native prpls:
  - [xmpp-ap-bridge](https://github.com/barbapulpe/xmpp-ap-bridge) — Python bot bridge, chat between Fediverse apps (Mastodon/Pixelfed/Friendica) and XMPP. v0.8.1 (2026-05-14). No E2EE; bridge operator is a person-in-the-middle.
  - [matrix-appservice-activitypub](https://github.com/Haven-Organization/matrix-appservice-activitypub) — Matrix application service bridging Matrix rooms to ActivityPub actors (Mastodon/Pleroma/Akkoma/Misskey), including both `Note` DMs and Pleroma/Akkoma `ChatMessage`.
  - [shoot](https://github.com/MaddyUnderStars/shoot) — native ActivityPub federated instant messenger (Node/Postgres), still WIP.
- **Model fit:** ActivityPub is a **subscription** protocol at heart — follow actors, receive `Create(Note)` activities into an inbox. Maps naturally to the user's "subscribe to channels of info" model. **Replies are first-class**: `Create(Note)` with an `inReplyTo` target is the standard reply flow, and replying from a followed channel is fully supported. Direct messaging (`Note` with `to` set) is the IM case.
- **E2EE:** Social Web Foundation + Emissary/Bonfire are building MLS-based E2EE for ActivityPub (targeting 2026) — not ready to depend on yet.
- **Server (self-contained test):** Mastodon self-hosts well (or any AP instance); two accounts on one instance, or two instances for true federation.

## Plan

1. **Decide approach** — options: (a) native minimal prpl speaking Mastodon-compatible client API + WebSocket streaming (OAuth2, timelines, statuses, DMs, follow, reply) — most Adium-native; (b) reuse an existing bridge (matrix-appservice-activitypub) as a shim and connect via the Matrix path. Research both, prefer (a) for a real transport.
2. **Server bootstrap** — local Mastodon (or lightweight AP instance) on an ephemeral port, two throwaway accounts.
3. **Smoke test** — scripted: (a) **subscription+reply** — Adium follows account B's feed, B posts, Adium's channel view surfaces it, Adium replies, B sees the reply; (b) **DM** — B DMs A, Adium receives and replies. Assert both.
4. **Teardown** — stop instance, drop accounts, delete temp profile.

## Out of scope (this iteration)

Public-key HTTP signatures beyond the basics, boosts/favorites/reactions, media, instance-discovery federation.

## Caveat

Mastodon API rate limits (≈300 calls/5 min) constrain the harness; keep polling gentle or use the streaming endpoint.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

