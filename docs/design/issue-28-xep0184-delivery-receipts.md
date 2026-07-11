# Design: XEP-0184 message delivery receipts

- **Issue:** [#28 — XEP-0184: message delivery receipts](../../../../issues/28)
- **Status:** Proposed
- **Scope:** `Plugins/Purple Service/` (new receipts glue + `ESPurpleJabberAccount`), `Plugins/WebKit Message View/` (delivered-state rendering), `Frameworks/Adium/Source/AIContentMessage.h/.m`

## 1. Problem

Zero references to XEP-0184 in the tree. Messages sent over XMPP give no
sent/delivered indication, and Adium never answers other clients' receipt
requests, so *their* delivery indicators stay stuck too.

## 2. Architecture context (read first)

- XMPP comes from libpurple 2.14.14's jabber prpl (vendored:
  `Dependencies/vendor/pidgin-2.14.14.tar.bz2`; prpl source inside it at
  `libpurple/protocols/jabber/`). XEP-0184 is **not** in libpurple 2.x core.
- The prpl emits `jabber-receiving-xmlnode` and `jabber-sending-xmlnode`
  signals that let code inspect **and mutate** every stanza without patching
  libpurple. Adium already uses exactly this pattern:
  `Plugins/Purple Service/AMPurpleJabberAdHocServer.m:115-117`.
- The jabber prpl exposes IPC calls via `purple_plugin_ipc_call` on the
  `prpl-jabber` plugin — including `"add_feature"` (adds a namespace to
  disco#info / entity caps) and `"contact_has_feature"`. Verify exact names and
  signatures in `libxmpp.c` in the vendored tarball before use.
- ObjC glue lives in `Plugins/Purple Service/` (`ESPurpleJabberAccount` is the
  jabber account class, `CBPurpleAccount` its superclass).

## 3. Design

Three layers: stanza plumbing (ObjC glue over the xmlnode signals), model
(stanza id on `AIContentMessage`), view (a `markDelivered(id)` JS hook).

### 3.1 Stanza plumbing — new class `AMPurpleJabberReceipts` (Purple Service)

Model the class on `AMPurpleJabberAdHocServer` (owned by
`ESPurpleJabberAccount`, connects the two xmlnode signals in its init,
disconnects on dealloc).

**On connect:** advertise `urn:xmpp:receipts` via the jabber `add_feature` IPC
call (once per process, it's global to the prpl).

**Outgoing (`jabber-sending-xmlnode`):** for chat `<message>` stanzas with a
`<body>`:
1. Ensure an `id` attribute exists (libpurple does not reliably set one on
   message stanzas — generate a UUID if missing).
2. Append `<request xmlns='urn:xmpp:receipts'/>`. Per XEP-0184 §5.4, only
   request when the recipient supports it if a full JID is known — use
   `contact_has_feature`; when the capability is unknown (bare JID), request
   anyway (spec-permitted, harmless).
3. Record `stanza-id → (chat, weak ref to the in-flight AIContentMessage)` in a
   pending map (see 3.2 for how the content message is available here).

**Incoming (`jabber-receiving-xmlnode`):**
1. `<message>` containing `<received xmlns='urn:xmpp:receipts' id='X'/>`:
   look up X in the pending map; if found, mark delivered (3.2) and remove.
   Swallow the stanza if it has no body (return without letting it become an
   empty message — check how the ad-hoc server suppresses handled stanzas).
2. `<message>` with a `<body>` **and** `<request xmlns='urn:xmpp:receipts'/>`:
   send `<message to='<sender full JID>' id='<new uuid>'>
   <received xmlns='urn:xmpp:receipts' id='<incoming id>'/></message>`.
   Do not reply to `type='error'` or `type='groupchat'` messages, and never
   reply from a receipt (no loops: receipts carry no `<request/>`).

### 3.2 Model — stanza id on the content object

Check `Frameworks/Adium/Source/AIContentMessage.h` for an existing unique
id/messageID property; reuse it if present, otherwise add
`@property (nonatomic, copy) NSString *stanzaID;`.

Send flow: `CBPurpleAccount` sends via libpurple, and the
`jabber-sending-xmlnode` signal fires synchronously inside that call — so the
glue can stash "id just assigned for chat C", and the account code can copy it
onto the `AIContentMessage` immediately after the send returns, before the
content object is displayed. Verify the display-after-send ordering in
`CBPurpleAccount`/content controller; if display precedes send, fall back to
notifying the view by chat + id after the fact (3.3 works either way).

Delivery notification: post an Adium notification
(`AIMessageDeliveredNotification`, userInfo: chat + stanza id) from the glue;
the WebKit controller for that chat observes it.

### 3.3 View — delivered indicator

In `Plugins/WebKit Message View/`:

1. When inserting an **outgoing** message whose content object has a stanzaID,
   wrap/annotate the inserted HTML with `id="msg-<stanzaID>"` (the insertion
   path is `AIWebkitMessageViewStyle` producing HTML consumed by
   `AIWebKitMessageViewController`; `Template.html` already carries JS helpers
   like `appendHTML` and `replaceLastMessage` — follow that pattern).
2. Add to `Template.html`:

   ```js
   function markDelivered(id) {
       var el = document.getElementById("msg-" + id);
       if (el) el.className += " delivered";
   }
   ```
3. `AIWebKitMessageViewController` observes the delivery notification for its
   chat and calls `markDelivered("<id>")` via the existing
   stringByEvaluatingJavaScriptFromString path.
4. Default rendering: inject a small CSS rule (e.g. a ✓ ::after on
   `.delivered`) from the plugin so all styles get it; individual message
   styles can override via the class.

## 4. Scope decisions

- One-to-one chats only; no groupchat receipts (XEP forbids them anyway).
- No timeout/"failed" state — absence of a receipt means nothing per spec.
- No preference toggle in v1: always request, always honor requests. Add a
  privacy pref only if someone asks (answering receipts does leak presence—
  if review pushes back, gate *answering* behind a default-on pref).

## 5. Verification

- Unit-test the stanza logic: feed xmlnodes through the handler functions
  (receipt reply generated with correct `id`, no reply to error/groupchat, no
  reply-to-receipt loop, UUID added to outgoing bodies). The xmlnode API is
  plain C — testable without a live connection.
- Manual: chat with Conversations/Monal/Gajim (all do 0184). Send → checkmark
  appears when their client acks; their client's delivery indicator works when
  Adium receives.
- `Plugins/Purple Service/` XML console (already in Adium) to eyeball stanzas.

## 6. Out of scope

- Chat markers / read state (XEP-0333): issue #30 builds directly on the id
  plumbing and `markDelivered` mechanism from this doc — implement this first.
- Carbons interplay (#23), MAM (#24).
