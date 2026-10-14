# Design: Smoke test: Jabber/XMPP with local Prosody server

- **Issue:** [#135 — Smoke test: Jabber/XMPP with local Prosody server](../../../../issues/135)
- **Status:** Proposed

## 1. Summary

# Smoke test: Jabber/XMPP (self-contained, Prosody server)

Part of epic #133. This fork ships the most Jabber work of any transport (XEP-0184 receipts, XEP-0333 chat markers, MAM, HTTP upload, carbons, ad-hoc commands — see `docs/xmpp-compliance.md`), so the harness must exercise real XMPP features, not just "connects".

## Research — server choice: **Prosody** (XMPP, Lua, lightweight)

- Very lightweight (runs on ~€1/month VPS per community reports), highly modular ("lego set"), config via a single `prosody.cfg.lua`.
- Supports the XEPs this fork implements: MAM (XEP-0313), HTTP Upload (XEP-0363), MUC (XEP-0045), PEP (XEP-0163), stream management, carbons, receipts.
- No official container image, but community images exist (e.g. a `debian:bookworm-slim` image with MAM/MUC/HTTP-upload/anti-spam preconfigured); or `brew install prosody` / distro package.
- Alternative if turnkey containers matter more: **ejabberd** (official Docker images, easier certs, Movim-tested). Prosody is the recommendation for lightweight + modular.
- Sources: [community prosody-docker](https://git.lainoa.eus/aitzol/prosody-docker), [self-host Prosody on Bazzite (2026)](https://azorius.vedetta.com/g/selfhosted@lemmy.world/p/8x4QJ7gCjw99Lg8JCy-How-to-self-host-a-Prosody-XMPP-server-on-Bazzite)

## Plan

1. **Bootstrap** — script starts Prosody on an ephemeral local port with a minimal `prosody.cfg.lua`: `anonymous`/plaintext auth or two throwaway users, MUC + MAM + HTTP upload modules enabled, self-signed or no TLS. `prosodyctl register` two accounts (`smoke-a`, `smoke-b`).
2. **Adium side** — create a Jabber account (`smoke-a`) pointing at `127.0.0.1:<port>`, throwaway profile (same isolation rule as the IRC harness).
3. **Send/receive assertion** — a second peer connects as `smoke-b` (second Adium instance, or a scripted XMPP client such as `slixmpp`/`python-xmpp`) and verifies:
   - Connect + roster: `smoke-a` sees `smoke-b` (and vice-versa).
   - 1:1 message both directions.
   - MUC: Adium creates/joins a temp room, writes, peer receives.
   - Feature smoke: message receipt ack (XEP-0184) and chat marker (XEP-0333) round-trip — these are fork patches, so assert the wire stanzas via the scripted peer.
   - MAM / HTTP upload deferred to a second pass (see out of scope).
4. **Teardown** — stop Prosody, delete temp profile and the two registered users.
5. **Repeatable** — `scripts/smoke/jabber.sh`, non-zero exit on any failed assertion.

## Out of scope (this iteration)

MAM archive retrieval, HTTP file upload, carbons, OMEMO — the compliance matrix (#123) covers the deep audit; this harness proves the connect/message path first, then feature stanzas.

## Related

- `docs/xmpp-compliance.md` — the fork's XEP coverage matrix to drive later feature smoke assertions.
- #123 (deep XEP audit) — compliance workstream this harness supports.

## 2. Approach

The test drives the transport through the app's own AppleScript interface, so
nothing is mocked and no other process touches the profile.

1. **Server** — Prosody from the `prosody/prosody` image runs as the `prosody`
   user, with a generated `prosody.cfg.lua` mounted read-only.
   TLS and s2s are off, plaintext authentication is on, and two throwaway
   accounts are registered with `prosodyctl` on an ephemeral port.
   A MUC component is available for the group-chat step.
2. **Profile** — `lib/profile.py` writes `Accounts.plist` and
   `AccountPrefs.plist` into a throwaway home.
   The account ID is the integer string `0`, because the app keys account
   preferences by that number, and `Type` selects the service
   (`libpurple-Jabber`) while `Service` holds the short name (`Jabber`).
3. **Password** — the app reads an account password from an internet-password
   item in the login keychain, keyed `<service>.<account>` with protocol
   `AdIM`. The test adds that item and removes it on exit.
4. **Launch** — the app runs with `CFFIXED_USER_HOME` set to the throwaway
   home, so the profile, the logs, and the caches stay inside it.
5. **Online** — the app starts every account offline.
   A preference does not connect it: `AIStatusController` only restores a
   status at launch, and `SLPurpleCocoaAdapter` connects when it sets an
   online status. The test therefore sends `go online` through AppleScript and
   waits until the account's status type reads `available`.
6. **Assertions** — the peer sends one token and waits for a reply token.
   The test waits for the incoming token in the app's chat log (receive path),
   sends the reply token from Adium through AppleScript (send path), and then
   waits for the peer process to exit with status 0.


## 3. Verification

- [ ] Verify fix/feature works as described

