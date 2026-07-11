# Design: XEP-0333 chat markers

- **Issue:** [#30 — XEP-0333: chat markers](../../../../issues/30)
- **Status:** Proposed
- **Depends on:** the delivery-receipts design (`issue-28-xep0184-delivery-receipts.md`) being implemented first — markers reuse its stanza-id plumbing, pending map, notification path, and view mechanism.
- **Scope:** `Plugins/Purple Service/` (extend the receipts glue), `Plugins/WebKit Message View/` (read-state rendering), chat-visibility hook in the message window layer

## 1. Problem

No displayed/read markers: Adium neither shows when a contact has read a
message nor tells other clients what the user has read. Pairs with XEP-0184
(issue #28); they share most of the plumbing, which is why #28's design builds
the shared pieces and this doc only adds the marker-specific parts.

## 2. Protocol summary (what to implement)

Namespace `urn:xmpp:chat-markers:0`.

- Outgoing chat messages may carry `<markable xmlns='urn:xmpp:chat-markers:0'/>`.
- A recipient that has *displayed* a markable message sends
  `<message to='…'><displayed xmlns='urn:xmpp:chat-markers:0' id='<stanza id>'/></message>`.
- `<received/>` and `<acknowledged/>` marker elements also exist; skip them —
  `<received/>` duplicates XEP-0184 and `<acknowledged/>` has no UI hook here.
  A `displayed` marker implies delivery of that message and all before it.

## 3. Design

Extend `AMPurpleJabberReceipts` (from #28) rather than adding a parallel class —
rename it `AMPurpleJabberMessageState` if that reads better; it owns both XEPs'
stanza work over the same two xmlnode signal connections.

### 3.1 Outgoing messages

In the existing `jabber-sending-xmlnode` hook, alongside the 0184
`<request/>`: add `<markable/>` to chat messages with a body. Advertise
`urn:xmpp:chat-markers:0` via the same `add_feature` IPC call used for
receipts.

### 3.2 Sending `displayed` (the read-tracking side — the only new moving part)

Send a `displayed` marker for the newest incoming markable message when the
user has actually seen it. "Seen" in Adium terms: the chat's message view is
visible and its window is key — find the existing signal for this (the
interface layer already tracks active chats for unread-count purposes; look in
`AIChatController` / interface controller notifications like
`Chat_BecameActive` / unviewed-content clearing, and hook where unviewed
content gets cleared — that is exactly the "user saw it" event).

Mechanics:
- The stanza glue records, per chat, the id + full JID of the last incoming
  message that carried `<markable/>` (and its `id`; if an incoming markable
  message has no id, it cannot be marked — skip).
- On the "chat viewed" event, if that id hasn't been marked yet, send the
  `displayed` stanza and remember it as marked. One marker per id, newest id
  only (a marker covers everything before it).

**Privacy pref (required, unlike receipts):** read receipts are the classic
leak. Gate *sending* `displayed` markers behind a preference, default **off**,
in the Privacy/Confidentiality preference pane
(`Plugins/Purple Service`-adjacent account prefs or the existing privacy pane —
implementer picks the nearest existing pane; do not build a new pane).
Requesting/rendering markers from others has no privacy cost and is always on.

### 3.3 Incoming `displayed` markers

In the `jabber-receiving-xmlnode` hook: `<message>` containing
`<displayed id='X'/>` → look up X in the pending map from #28. Mark that
message *and every earlier outgoing message in the same chat* as read.
Swallow the stanza (no body).

Notification: reuse the #28 notification path with a state field
(`delivered` | `displayed`) instead of adding a second notification.

### 3.4 View

Extends #28's mechanism in `Plugins/WebKit Message View/Template.html`:

```js
function markDisplayed(id) {
    // marker covers this message and all earlier ones
    var el = document.getElementById("msg-" + id);
    for (; el; el = previousMessageElement(el))  // walk previous siblings with msg- ids
        el.className = el.className.replace(" delivered", "") + " displayed";
}
```

Default CSS: `.displayed` gets the double-check / filled indicator, replacing
the `.delivered` single check. Same injection point as #28.

## 4. Scope decisions

- 1:1 chats only. Groupchat markers are a different UX problem entirely.
- `<received/>` and `<acknowledged/>` markers: not implemented (see §2).
- No per-contact override for the send pref in v1 — one global toggle.

## 5. Verification

- Unit tests on the stanza handlers (same style as #28): markable added on
  send; displayed marker emitted once and only for the newest id; incoming
  displayed maps to the right ids; pref off ⇒ no marker sent.
- Manual against Conversations or Gajim: their read state updates when the
  Adium chat is foregrounded (pref on); Adium shows their read state on sent
  messages.

## 6. Out of scope

- XEP-0184 itself (#28 — prerequisite), carbons (#23), MAM (#24). When carbons
  land, `displayed` markers also sync read state across own devices for free —
  no extra work here, noted so nobody builds it twice.
