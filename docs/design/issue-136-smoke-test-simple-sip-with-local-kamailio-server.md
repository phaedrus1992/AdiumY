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

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

