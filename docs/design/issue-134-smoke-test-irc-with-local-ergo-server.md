# Design: Smoke test: IRC with local Ergo server

- **Issue:** [#134 — Smoke test: IRC with local Ergo server](../../../../issues/134)
- **Status:** Proposed

## 1. Summary

# Smoke test: IRC (self-contained, Ergo server)

Part of epic #133. Replace the one-off public-server IRC smoke test with a self-contained harness.

## Research — server choice: **Ergo** (formerly Oragono)

- Single Go binary, MIT-licensed, actively maintained (v2.18.0, March 2026; ~77 releases).
- One binary = ircd + NickServ/ChanServ + TLS + SASL + IRCv3; history replay built in.
- Install: `brew install ergo`, or download a release tarball, or Docker `ghcr.io/ergochat/ergo`.
- Bootstrap: `cp default.yaml ircd.yaml` → edit → `./ergo mkcerts` → `./ergo run`. No services daemon, no external DB needed.
- Sources: [ergochat/ergo](https://github.com/ergochat/ergo), [FreshPorts irc/ergo](https://www.freshports.org/irc/ergo/), [NewReleases v2.18.0](https://newreleases.io/project/github/ergochat/ergo/release/v2.18.0), [Run Your Own IRC Server (Ergo)](https://tomsitcafe.com/2026/03/27/run-your-own-irc-server/)

## Plan

1. **Bootstrap** — script starts Ergo on an ephemeral local port (brew binary preferred; Docker as fallback), generates a throwaway `ircd.yaml` (unique server name, no TLS or self-signed, passwordless nick registration).
2. **Adium side** — create an IRC account pointing at `127.0.0.1:<port>`, no saved password. Scripted via `defaults` write to a throwaway Adium profile (isolated `~/Library/Application Support/Adium 2`), not the real profile.
3. **Send/receive assertion** — a second peer connects (netcat IRC client script or a second Adium instance) and verifies:
   - Adium connects and is visible in the channel's nick list.
   - Adium writes a marker message to a temp channel (`#smoke-<timestamp>`); the peer sees it arrive.
   - The peer sends back; Adium displays it (assert via log file or UI dump).
4. **Teardown** — kill Ergo, delete temp profile and channel registration.
5. **Repeatable** — one command (`scripts/smoke/irc.sh`), exits non-zero on any failed assertion.

## Out of scope (this iteration)

IRCv3 SASL, TLS, bouncer/history — Ergo supports them; wire them in later once the basic harness is green.

## 2. Approach

The test drives the transport through the app's own AppleScript interface, so
nothing is mocked and no other process touches the profile.

1. **Server** — Ergo from `ghcr.io/ergochat/ergo:stable` runs with a generated
   `ircd.yaml` mounted read-only: one plaintext listener on an ephemeral
   published port, account registration and SASL off, so a client connects
   with a nickname alone. The `limits` block comes from the image's own
   defaults, because Ergo refuses to start below its minimum values.
2. **Profile** — `lib/profile.py` writes the account with type
   `libpurple-IRC` and the nickname as the UID, pointing at `127.0.0.1` with
   `IRC:Use SSL` false. No password is stored: `ESIRCService` returns NO from
   `requiresPassword`.
3. **Peer** — `peers/irc_peer.py` speaks IRC over a plain socket, with the
   standard library only. It sends one token and waits for a reply token.
   IRC drops a message for a nickname that is not connected, and answers
   `401 No such nick`, so the peer sends again until the app appears.
4. **Channel** — the app joins a channel through its own URL handler
   (`irc://127.0.0.1:<port>/#smoke-<token>`), the peer joins the same channel,
   and the peer waits until it sees the app's nickname in it.
5. **Assertions** — the test waits for the incoming token in the app's chat
   log (receive path), sends the reply token from Adium through AppleScript
   (send path), and then waits for the peer process to exit with status 0.


## 3. Verification

- [ ] Verify fix/feature works as described

