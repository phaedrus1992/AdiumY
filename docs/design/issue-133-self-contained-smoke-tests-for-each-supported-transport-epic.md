# Design: Self-contained smoke tests for each supported transport (epic)

- **Issue:** [#133 — Self-contained smoke tests for each supported transport (epic)](../../../../issues/133)
- **Status:** Proposed

## 1. Summary

# Self-contained smoke tests for each supported transport

**Epic.** Goal: a repeatable, local, self-contained smoke-test suite that verifies each transport this fork ships (or adds) actually connects and exchanges messages — no public servers, no credentials, no flaky network.

## Why

The debug app builds and launches, and we ran a one-off IRC smoke test against a public network (freenode-era workflow). That's not repeatable: it needs internet, an available public server, and manual setup. Each transport needs a **self-contained** harness — a local server (or, for Bonjour, none at all) plus a scripted send/receive assertion that can run in CI and locally on demand.

## Model

Not every transport is strict instant messaging. Transports fall into two (overlapping) models, and both are in scope:

- **IM** — send + receive messages between two identities (IRC, Jabber, SIMPLE, Bonjour, Discord, Slack, Matrix, atproto DMs, ActivityPub DMs).
- **Subscribe to channels of info** — a transport is a stream of posts/entries the user follows (RSS/Atom, atproto feeds, ActivityPub timelines). Replies are supported where the protocol allows (atproto, ActivityPub). See the RSS/Atom, atproto, and ActivityPub sub-issues.

## Transports (confirmed in the build)

| Transport | Protocol | Local server | Status |
|-----------|----------|--------------|--------|
| IRC | `prpl-irc` | Ergo (Go, single binary) | public-server smoke test done; needs self-contained harness |
| Jabber/XMPP | `prpl-jabber` | Prosody | not yet smoke-tested |
| SIMPLE/SIP | `prpl-simple` | Kamailio | not yet smoke-tested |
| Bonjour | Adium's own EZV P2P (mDNS `_presence._tcp`) | none needed (peer-to-peer) | not yet smoke-tested |

## Proposed transports (add support + smoke test)

| Transport | Model | Local server | Research status |
|-----------|-------|--------------|-----------------|
| Discord | IM | Spacebar (verify) | mature plugin exists: purple-discord |
| Slack | IM | local Socket Mode / Web API mock (no self-hostable server) | no maintained plugin; RTM deprecated |
| Matrix | IM | Synapse (Docker) | old plugin unmaintained; purple-matrix-rust (2026) |
| atproto (Bluesky) | IM + subscribe/reply | local PDS | greenfield; XRPC + firehose + chat.bsky.convo |
| ActivityPub | subscribe/reply + DM | Mastodon (or any AP instance) | greenfield; bridges exist, no native prpl |
| RSS/Atom | subscribe | local fixture feed server | greenfield; no current prpl |

## Old/dead protocols (investigation)

| Protocol | Local server | Research status |
|----------|--------------|-----------------|
| AIM / ICQ | open-oscar-server (active, Go) | investigation issue open |

## Shared requirements (every sub-issue)

1. **Server bootstrap** — a local, scripted way to start the server with a known, ephemeral port and no external dependencies (brew formula, Docker image, or downloaded binary — pick the most portable, prefer brew).
2. **Deterministic config** — two throwaway accounts/identities created on the fly; no saved passwords.
3. **Send/receive assertion** — a scripted second peer (second Adium instance, or a small protocol client) that verifies a message written by Adium actually arrives, and vice-versa. Must fail loudly, not just "ran without crashing". For subscribe-model transports, the assertion is: a new entry/post published by the server appears in Adium's channel view.
4. **Teardown** — server and accounts cleaned up; no state leaked into the user's real Adium profile.
5. **Repeatable** — runnable via one command, locally and in CI.

## Deliverables

- One sub-issue per transport, each with a basic plan.
- A shared runner script (`scripts/smoke/` or similar) that all transports plug into.
- A shared "channel subscription" abstraction for the subscribe-model transports (RSS/Atom, atproto, ActivityPub) — design early, see those sub-issues.

## Sub-issues

- [ ] #134 — Smoke test: IRC with local Ergo server
- [ ] #135 — Smoke test: Jabber/XMPP with local Prosody server
- [ ] #136 — Smoke test: SIMPLE/SIP with local Kamailio server
- [ ] #137 — Smoke test: Bonjour (peer-to-peer, no server)
- [ ] #138 — Support: Discord transport
- [ ] #139 — Support: Slack transport
- [ ] #140 — Support: Matrix transport
- [ ] #141 — Support: atproto (Bluesky) transport
- [ ] #142 — Support: ActivityPub transport
- [ ] #143 — Support: RSS/Atom transport
- [ ] #144 — Investigate: revive old/dead protocols (AIM, ICQ) via open-source servers

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

