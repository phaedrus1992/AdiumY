# Design: Smoke test: SIMPLE/SIP with local Kamailio server

- **Issue:** [#136 — Smoke test: SIMPLE/SIP with local Kamailio server](../../../../issues/136)
- **Status:** Proposed

## 1. Summary

# Smoke test: SIMPLE/SIP (self-contained, Kamailio server)

Part of epic #133. `prpl-simple` is the least-used transport in this fork (SIP/SIMPLE presence + IM), but it ships in the build (`--with-static-prpls=jabber,irc,simple`) and has zero smoke-test coverage today.

## Research — server choice: **Kamailio** (SIP, SIMPLE-native)

- Open-source C SIP server; **native SIMPLE presence** support: embedded XCAP server, MSRP relay, presence agent modules — the only mainstream server that does SIMPLE IM + presence out of the box.
- Modular (>100 modules), handles UDP/TCP/SCTP/TLS/WebSocket; Docker images available.
- Lightweight alternative: **Routr** (a SIP proxy/registrar/location server, one-command Docker, `fonoster/routr-one`), but its SIMPLE *presence* support is undocumented — Kamailio is the recommendation for presence.
- Sources: [Kamailio — SIMPLE/SIP server](https://get.alternative.to/kamailio/overview), [awesome-selfhosted SIP](https://mintlify.wiki/awesome-selfhosted/awesome-selfhosted/categories/communication/sip), [Routr](https://github.com/fonoster/routr), [containerised VoIP lab (Kamailio + Asterisk)](https://github.com/Ahmedaltu/asterisk-voip-lab)

## Plan

1. **Bootstrap** — script starts Kamailio on an ephemeral local port with a minimal config: registrar + presence + SIMPLE IM modules, two throwaway SIP accounts (`smoke-a`, `smoke-b`) with known creds.
2. **Adium side** — create a SIMPLE account (`smoke-a`) pointing at `127.0.0.1:<port>`, throwaway profile (same isolation rule as IRC/Jabber). Uses the SIP proxy + presence publish prefs in `ESPurpleSimpleAccount.m`.
3. **Send/receive assertion** — a second peer (second Adium instance as `smoke-b`, or a scripted SIP client such as `pjsip`/`baresip`) verifies:
   - Both accounts register with the registrar.
   - Presence: `smoke-a` publishes; `smoke-b` observes the status change (and vice-versa).
   - 1:1 message both directions.
4. **Teardown** — stop Kamailio, delete temp profile and accounts.
5. **Repeatable** — `scripts/smoke/simple.sh`, non-zero exit on any failed assertion.

## Caveat

`prpl-simple` in libpurple is old and minimally maintained. If the connect or presence path is broken at the prpl level, this harness will expose it — treat that as a valid result (file the prpl bug separately), not a reason to skip the harness.

## Out of scope (this iteration)

SIP TLS, MSRP file transfer, voice/video — presence + IM smoke only.

## 2. Approach

The plan, and what the transport allows on a machine with Docker.

1. **Server** — Kamailio 6.0.8 from `ghcr.io/kamailio/kamailio-ci` with a
   generated `kamailio.cfg`: a registrar with no authentication, and a
   `MESSAGE` route that looks the target up and relays. The module order
   matters — a module that uses `tm` or `usrloc` must load after it — so the
   config keeps the order of the image's own default file.
2. **Profile** — type `libpurple-simple`, service `SIMPLE`, and the account
   preferences `Simple:Use UDP` (false selects TCP) and
   `Simple:Publish Status`, both read by `ESPurpleSimpleAccount.m`.
3. **Peer** — a scripted SIP client speaking UDP or TCP with the standard
   library only: REGISTER with the account as the address of record, then one
   MESSAGE. The spike was removed rather than committed, because a test that
   cannot pass on the development machine does not belong in the suite.
4. **Blocked: delivery.** A client on the host registers successfully, but the
   server in the container can open no connection back to the client's
   ephemeral SIP port. A `MESSAGE` to that client ends in `408 Request
   Timeout`, with and without `fix_nated_contact()`. The published port is the
   only address the container can reach.
   Docker on macOS forwards TCP but not UDP, so SIP's default transport
   reaches no container at all.
   A Linux runner with `--network host`, or a SIP server that runs natively on
   macOS, removes the problem. There is no brew formula for Kamailio today.


## 3. Verification

- [ ] Verify fix/feature works as described

