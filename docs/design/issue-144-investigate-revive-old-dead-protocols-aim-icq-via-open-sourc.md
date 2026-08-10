# Design: Investigate: revive old/dead protocols (AIM, ICQ) via open-source servers

- **Issue:** [#144 — Investigate: revive old/dead protocols (AIM, ICQ) via open-source servers](../../../../issues/144)
- **Status:** Proposed

## 1. Summary

# Investigate: revive old/dead protocols (AIM, ICQ, …) via active open-source servers

Part of epic #133 (investigation — add support + self-contained smoke test if viable).

## Motivation

Classic protocols shut down their official networks (AOL AIM 2017, ICQ 2024), but **active open-source server implementations** now exist that speak the original wire protocols. libpurple's `oscar` prpl (which Adium used for AIM/ICQ) is still in libpurple — this fork just doesn't build it (`--with-static-prpls=jabber,irc,simple`). Bringing back a dead protocol as a **self-contained local transport** is a cheap, safe, historically-fun win: no public network, no credentials beyond a throwaway local account.

## Research

- **Leading project:** [open-oscar-server](https://github.com/mk6i/open-oscar-server) (formerly Retro AIM Server; mk6i, Go, MIT, actively maintained). Self-hostable server compatible with classic AIM and ICQ clients.
  - Implements **OSCAR** and **TOC** protocols, multi-server architecture (Auth 5190, BOS 5191, Chat 5192, …) or single-service mode (default 5190) since v0.21.0. SQLite storage; env-var or config-file config.
  - **ICQ (v0.24.0):** legacy pre-OSCAR UDP clients (ICQ 98x/99x/Groupware, port 4000) + OSCAR ICQ 2000–2005 + third-party (Jimm, QIP). AIM↔ICQ cross-protocol messaging.
  - **AIM:** Windows AIM 1–7, TOC1/TOC2 clients (Quick Buddy, gaim, TiK, vAIM, Miranda), buddy lists, chat rooms, away messages, profiles, offline messages, file sharing.
  - macOS builds (Intel + Apple Silicon) documented; runs via `docker`, `brew`, or release binary.
- **Second effort:** [ox/aim-oscar-server](https://github.com/ox/aim-oscar-server) (Go, smaller); NINA (Level Leap, commercial-gated beta).
- **Sources:** [releases](https://github.com/mk6i/open-oscar-server/releases), [Korben review](https://korben.info/en/open-oscar-server-bring-aim-back-to-life-old-machines.html), [The Register (ICQ/NINA)](https://www.theregister.com/software/2024/05/31/icq-may-shut-down-but-nina-may-yet-resurrect-it/)

## Plan

1. **Inventory candidate protocols** — AIM (OSCAR/TOC), ICQ (legacy + OSCAR); also scan for active open-source servers for MSN/Windows Live, Yahoo!, Gadu-Gadu, others. For each: is the libpurple prpl still in-tree, and does an active server exist?
2. **Enumerate in-tree prpls** — libpurple 2.14 ships `oscar` (AIM/ICQ), `msn`, `yahoo`, `gg`, `novell`, etc. This fork compiles only jabber/irc/simple; document what's available to enable and what would need vendoring back.
3. **Proof of concept (AIM or ICQ first)** — build open-oscar-server locally, enable libpurple `oscar` in this fork's build, connect an Adium AIM/ICQ account to `127.0.0.1:5190`, verify sign-on + buddy list + message exchange.
4. **Report + decide** — produce a findings write-up: protocol × server × prpl viability matrix. For each viable pair, either file a follow-up "support + smoke test" issue (mirroring the other transport sub-issues in this epic) or explicitly mark not-worth-it with reasons.
5. **Smoke test (if any pair is viable)** — mirror the epic's shared requirements: server bootstrap, throwaway accounts, scripted send/receive assertion, teardown, one-command runner.

## Out of scope

Resurrecting *public* AIM/ICQ networks (there is no official one to join) — this is purely a self-contained, local-network/loopback transport. Legacy UDP ICQ and OSCAR-ICQ are separate prpl paths; test at least one to prove the concept, then decide.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

