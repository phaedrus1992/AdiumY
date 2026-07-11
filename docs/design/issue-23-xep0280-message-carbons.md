# Design: XEP-0280 message carbons

- **Issue:** [#23 — XEP-0280: message carbons](../../../../issues/23)
- **Status:** Proposed
- **Scope:** `Plugins/Purple Service/libpurple_extensions/` (new C plugin, ported or written fresh), `Plugins/Purple Service/` (registration + account pref)

## 1. Problem

No carbons: with any second logged-in device, messages sent or received on the
other device never appear in Adium — conversations are missing half their
content. libpurple 2.x core has no XEP-0280 (libpurple 3 does; irrelevant here,
we vendor pidgin 2.14.14).

## 2. Protocol summary

Namespace `urn:xmpp:carbons:2`.

- After login, if the server's disco#info advertises `urn:xmpp:carbons:2`,
  send `<iq type='set'><enable xmlns='urn:xmpp:carbons:2'/></iq>`.
- The server then wraps copies of messages to/from the user's other devices in
  `<message from='<own bare JID>'>` containing
  `<received xmlns='urn:xmpp:carbons:2'>` or `<sent …>` with a
  `<forwarded xmlns='urn:xmpp:forward:0'>` holding the original `<message>`.
- **Security rule (non-negotiable):** only honor carbon wrappers where the
  outer `from` is the user's **own bare JID**. Anything else is a spoofing
  attempt — discard the wrapper and deliver nothing.
- Messages can opt out with `<private xmlns='urn:xmpp:carbons:2'/>`; the
  receiving side needs no handling for that (the server just won't copy them).

## 3. Design

### 3.1 Starting point: port `gkdr/carbons`

`gkdr/carbons` (github.com/gkdr/carbons) is a mature third-party libpurple 2
plugin: single `carbons.c`, public libpurple API only, works via the
`jabber-receiving-xmlnode` signal and `purple_signal_connect` on
`account-signed-on`. Port it into
`Plugins/Purple Service/libpurple_extensions/carbons.c` alongside the existing
`ssl-cdsa.c` etc.

**License check first:** Adium is GPLv2 (see `License.txt`); confirm
gkdr/carbons' current license is GPLv2-compatible before vendoring. If it is
GPLv3-only, do **not** vendor — write it fresh instead; the whole XEP is
roughly 300 lines of xmlnode handling (enable IQ on signed-on + unwrap two
wrapper shapes + the bare-JID check), and this doc plus the XEP text is enough
spec. Either way the rest of this design is identical.

What the plugin does (port or rewrite):

1. `account-signed-on` (jabber accounts only): disco the server for
   `urn:xmpp:carbons:2`; if present, send the enable IQ. Retry/failure = log
   and move on (carbons off is degraded, not broken).
2. `jabber-receiving-xmlnode`:
   - Validate outer `from` == own bare JID (else drop wrapper, deliver
     nothing, log).
   - `<received>` carbon: replace the stanza's content with the forwarded
     inner `<message>` so the prpl processes it exactly as if it arrived
     directly — the existing conversation plumbing, logging, and (once #28/#29
     land) receipts/corrections all just work.
   - `<sent>` carbon: extract the inner message and write it into the
     conversation as an **outgoing** message
     (`purple_conversation` API with the `PURPLE_MESSAGE_SEND` flag, no
     re-send). This is the "you typed this on your phone" echo.

### 3.2 Adium integration

- **Build/registration:** compile `carbons.c` into the Purple Service target.
  It is a *purple plugin*, not a core file like `ssl-cdsa.c` — check how
  Purple Service initializes libpurple (`adiumPurpleCore.m`) and register the
  plugin's init there the same way other compiled-in purple plugins are probed
  (if the target has no precedent for a compiled-in plugin, call the plugin's
  init/load functions directly from the core init — keep it static, do not
  introduce dynamic plugin loading).
- **Echo display:** verify that a `PURPLE_MESSAGE_SEND`-flagged write reaches
  Adium's message view as an outgoing message (trace
  `adiumPurpleConversation.m`'s conversation-write callbacks). This is the one
  integration point most likely to need a fix — Adium may assume outgoing
  messages always originate from its own send path. Budget the debugging here.
- **Pref:** per-account "Synchronize with other devices (message carbons)"
  checkbox in `ESPurpleJabberAccountViewController`, default **on**. Off ⇒
  skip the enable IQ (and send `<disable/>` if currently enabled).

### 3.3 Ordering note

The issue list runs carbons before MAM (#24) deliberately: MAM's dedup design
assumes carbons already deliver live traffic. Nothing in this doc depends on
#28/#29/#30, but their features ride through carbons automatically once both
sides exist.

## 4. Verification

- Unit tests on the unwrap logic with hand-built xmlnodes: spoofed outer
  `from` dropped; `<received>` unwraps to inner message; `<sent>` produces a
  SEND-flagged write to the right conversation; malformed/empty `<forwarded>`
  ignored without crash.
- Manual, two devices on one account (Adium + Conversations, any carbons-y
  server — ejabberd/Prosody defaults):
  1. Send from phone → message appears in Adium's chat as outgoing.
  2. Contact replies while phone is foreground → reply appears in Adium too.
  3. XML console shows the enable IQ result on connect.
- Toggle the pref off, reconnect → no enable IQ, no carbon traffic.

## 5. Out of scope

- MAM/offline history (#24). Carbons only cover messages while connected.
- Groupchat (MUC has no carbons; not applicable).
- OMEMO-encrypted carbon payloads (#27's problem).
