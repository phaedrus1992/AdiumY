# Design: XEP-0308 last message correction (receive side)

- **Issue:** [#29 — XEP-0308: last message correction](../../../../issues/29)
- **Status:** Proposed
- **Depends on:** per-message DOM ids in the message view from the receipts design (`issue-28-xep0184-delivery-receipts.md` §3.3) — extend that mechanism to incoming messages here.
- **Scope:** `Plugins/Purple Service/` (stanza glue), `Plugins/WebKit Message View/` (in-place content swap)

## 1. Problem

No XEP-0308 support: when a contact edits a message, the correction arrives as
a brand-new message, so conversations show duplicates instead of replacing the
original. libpurple 2.14's jabber prpl has no 0308 handling.

## 2. Protocol summary

Namespace `urn:xmpp:message-correct:0`. A correction is a normal `<message>`
with a `<body>` (the corrected text) plus
`<replace id='<id of the message being corrected>'
xmlns='urn:xmpp:message-correct:0'/>`. Spec restricts correction to the *last*
message from that sender in that conversation. Advertise the namespace in
disco (via the `add_feature` jabber IPC call, same pattern as #28).

## 3. Design

**Receive-only in v1.** Sending corrections needs an editing UI in the message
entry view — real design work, zero protocol difficulty. Split it out (see §6).

### 3.1 Prerequisite extension: DOM ids on incoming messages

#28 gives *outgoing* messages `id="msg-<stanzaID>"` in the WebKit view. Extend
the same insertion path so **incoming** messages get it too, keyed on the
incoming stanza's `id` attribute plus the sender (corrections are scoped per
sender): `id="msg-in-<sha or escaped sender>-<stanza id>"` — any scheme works
as long as the glue and the view compute it identically; keep it in one shared
helper.

### 3.2 Stanza glue (`jabber-receiving-xmlnode`)

In the same signal-handler class as #28/#30 (one class owns all
message-extension stanza work):

1. Track, per (chat, sender full JID): the stanza id of the last message with
   a body — one string per sender, overwritten on every message. (This also
   validates the "last message only" rule.)
2. On `<message>` with `<replace id='X'/>` and a body:
   - If X matches the tracked last-message id from that sender: post a
     correction notification (chat, sender, X, new body already run through
     Adium's normal message HTML processing) and **strip the message from
     normal display** (swallow it after dispatch, like receipt stanzas).
   - If X does not match (out-of-order, restart, or malicious replace of an
     older message): fall through — deliver as a normal message. Never let a
     `<replace/>` rewrite anything but the sender's last message; that's the
     spec's anti-spoofing rule, treat it as a hard rule, not a nicety.
3. After a correction, update the tracked id to the correction's own stanza id
   (corrections of corrections chain through the latest id, per XEP).

### 3.3 View — in-place swap

`AIWebkitMessageViewStyle.m:55` already defines
`REPLACE_LAST_MESSAGE  @"replaceLastMessage(\"%@\");"` and message styles ship
a `replaceLastMessage()` JS function — but that replaces the *globally* last
message, which is wrong when someone else spoke in between. Use it only as
fallback:

1. Add to `Template.html`:

   ```js
   function correctMessage(domId, html) {
       var el = document.getElementById(domId);
       if (!el) return false;
       el.innerHTML = html;            // html is the fully-styled message body
       el.className += " corrected";
       return true;
   }
   ```

   The controller builds `html` by running the corrected body through the same
   `AIWebkitMessageViewStyle` content formatting as any message body.
2. `AIWebKitMessageViewController` observes the correction notification for
   its chat: try `correctMessage("msg-in-…-X", html)`; if it returns false
   (message scrolled out of the loaded view or predates the window), append
   the correction as a normal message so nothing is ever silently dropped.
3. Default CSS: `.corrected::after` renders a small "(edited)" tag; styles can
   override.

### 3.4 Transcripts / logging

The original message is already logged by the time a correction arrives.
Log the correction as a normal message (it will read as a near-duplicate in
logs). Rewriting transcript logs in place is explicitly out of scope — flag in
the PR so it can become a follow-up issue if it bothers anyone.

## 4. Verification

- Unit tests on the stanza handler: replace-of-last accepted; replace of
  non-last delivered as normal message; chained corrections track the newest
  id; missing body ignored.
- Manual: edit a message from Gajim or Conversations → Adium swaps the bubble
  in place with an "(edited)" tag; edit twice → still one bubble; send an
  intervening message from a second contact → correction still lands on the
  right bubble (this is the case `replaceLastMessage` would get wrong).

## 5. Out of scope

- Sending corrections (edit-last-message UI in the entry area). File a
  follow-up issue when this lands.
- Corrections in group chats (needs occupant-id to be safe; skip).
- Rewriting transcript logs (§3.4).
