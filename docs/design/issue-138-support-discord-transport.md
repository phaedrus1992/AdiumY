# Design: Support: Discord transport

- **Issue:** [#138 — Support: Discord transport](../../../../issues/138)
- **Status:** Proposed

## 1. Summary

# Support: Discord transport

Part of epic #133 (add support + self-contained smoke test).

## Research

- **Existing plugin:** [purple-discord](https://github.com/EionRobb/purple-discord) (EionRobb, GPLv3) — mature, actively maintained libpurple plugin for Discord. Supports multiple accounts, rich text, custom emoji, QR auth, mentions, image display. Packaged as FreeBSD port `net-im/purple-discord` (2026Q2, updated 2026-06-22). Uses the Discord WebSocket gateway (JSON), not a proprietary trick.
- **Server (self-contained test):** Discord itself is proprietary cloud, so a local harness needs a Discord-compatible server. Candidate: **Spacebar** (open-source Discord-compatible server, fosscord successor) — verify current status + client compatibility before committing. Fallback: a throwaway Discord test guild + bot token (less self-contained).

## Plan

1. **Decide build path** — vendor/build purple-discord as a libpurple prpl (matches the existing `--with-static-prpls=jabber,irc,simple` model), or implement a minimal prpl in-tree. Prefer vendoring the maintained plugin first.
2. **Server bootstrap** — evaluate Spacebar for a local Discord-compatible server; document the working recipe (ephemeral port, throwaway guild/channel/bot).
3. **Smoke test** — scripted: bot joins a channel, Adium writes a marker message, bot asserts receipt; reverse direction too. Throwaway profile isolation (per epic #133 shared requirements).
4. **Teardown** — stop server, drop bot/guild, delete temp profile.

## Out of scope (this iteration)

Voice, screenshare, rich embeds, slash-command execution, full gateway event handling beyond messages.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

