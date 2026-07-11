# Design: Migrate the WebKit Message View to WKWebView

- **Issue:** [#9 — migrate WebKit Message View to WKWebView](../../../../issues/9)
- **Status:** Proposed
- **Scope:** `Plugins/WebKit Message View/` (whole plugin), `Plugins/Purple Service/AMPurpleRequestFieldsController`, `Source/ESiTunesPlugin`, `Source/AIInterfaceController.m` (incidental WebView reference)
- **This is the hairiest migration in the app.** Do it last among the modernization issues; do NOT interleave with the ARC conversion of the same plugin (#38) — sequence them (either order, never one PR).

## 1. Current state

The message view is legacy WebView (deprecated 10.14) plus private API:

| File | Role / migration pain |
|---|---|
| `ESWebView.{h,m}` | WebView subclass (drag/drop, transparency) — becomes WKWebView subclass |
| `AIWebKitDelegate.{h,m}` | frame-load/policy delegates — becomes WKNavigationDelegate/WKUIDelegate |
| `AIWebKitMessageViewController.m` (1772 lines) | the core; **synchronous DOM access** (`DOMDocument`, `stringByEvaluatingJavaScript`) throughout |
| `AIWebkitMessageViewStyle.m` (1488 lines) | HTML/keyword templating — mostly WebView-independent, smallest changes |
| `AIAdiumURLProtocol.{h,m}` | custom `adium://` NSURLProtocol — WKWebView ignores NSURLProtocol; becomes `WKURLSchemeHandler` |
| `WebKitPrivateDefinitions.h` | private WebKit API — must die, no replacement lookup |
| `ESWebFrameViewAdditions`, `JVFontPreviewField`, prefs classes | mechanical updates |
| `Plugins/Purple Service/AMPurpleRequestFieldsController.m` (26.8K) + nib | renders purple request forms in a WebView — same treatment, separate PR |
| `Source/ESiTunesPlugin.m` | trivial WebView use — same treatment, separate PR |

## 2. The architectural change (everything else is detail)

WebView allowed ObjC to read/mutate the DOM synchronously and get JS return
values inline. WKWebView runs content out-of-process: JS execution is
async-with-completion-handler, DOM access is JS-only, ObjC↔JS messaging goes
through `WKScriptMessageHandler`.

Consequence: `AIWebKitMessageViewController` must stop *asking* the page
anything mid-flow. Redesign to **one-way command stream + event callbacks**:

- **ObjC → page:** every mutation (append message, replace last, mark
  delivered, set style setting) is a JS function call via
  `evaluateJavaScript:completionHandler:`. `Template.html` already has this
  shape (`appendHTML`, `replaceLastMessage`, the CoalescedHTML queue) — the
  contract extends, it doesn't change.
- **Page → ObjC:** anything ObjC currently *reads* from the DOM (scroll
  position queries, content-ready checks, selection for copy behavior,
  element hit-testing for context menus) becomes either (a) an event the
  page pushes via `window.webkit.messageHandlers.adium.postMessage(...)`, or
  (b) state ObjC already knows because it sent it. Inventory every
  `DOMDocument`/`stringByEvaluatingJavaScript` **read** in the controller
  first (grep; expect a few dozen) and classify each as (a)/(b)/delete —
  this inventory is step 1 of implementation and the best effort estimate.
- **Queue-until-ready:** WKWebView loads async; all commands buffer until
  the page posts "ready" (the plugin already queues during style load —
  generalize that path rather than adding a second queue).

## 3. Migration map (per-PR sequence)

1. **Scheme handler.** `AIAdiumURLProtocol` → `WKURLSchemeHandler`
   registered on the `WKWebViewConfiguration` (`adium://` serves style
   resources/avatars). Also set `allowFileAccessFromFileURLs`-equivalent
   properly: styles load from disk — use
   `loadFileURL:allowingReadAccessToURL:` scoped to the style bundle + the
   transcripts/emoticon dirs actually referenced.
2. **The read inventory + Template.html contract** (§2). Pure analysis +
   JS: extend Template.html with the postMessage event side; testable in a
   bare WKWebView harness before the controller moves.
3. **Controller cutover.** `ESWebView` → WKWebView subclass;
   `AIWebKitDelegate` → navigation/UI delegates + script message handler;
   controller rewritten against the §2 contract. This PR is the big one and
   it is all-or-nothing per view (WebView and WKWebView can't share one
   view instance) — but the *app* keeps a fallback: keep the old classes
   compiling until step 5.
4. **Feature parity pass** against known style-dependent behaviors:
   message styles (test several: the repo ships defaults; also a
   third-party Adium xtra style), variants, custom CSS, background images
   & transparency (WKWebView transparency: `drawsBackground`/underPageBackgroundColor
   differences), context menus (WKWebView has its own menu machinery —
   Adium's per-message menu items need `WKUIDelegate` / JS hit-test events),
   drag-and-drop of files into the view, text selection & copy, scrollback
   behavior, find-in-page if present.
5. **Delete** legacy: `WebKitPrivateDefinitions.h`, NSURLProtocol class, any
   remaining WebView imports. `git grep -l "WebKit/WebView.h\|DOMDocument"`
   → zero hits in first-party code.
6. **Satellites** (independent, any time after 1): `AMPurpleRequestFieldsController`
   (evaluate first whether its form rendering even needs a web view — a
   native NSView form generator may be *less* work than porting; decide in
   that PR) and `ESiTunesPlugin` (trivial; also evaluate deletion — an
   iTunes/Music integration may be dead functionality worth an issue of its
   own rather than a port).

## 4. What is deliberately NOT preserved

Behaviors that exist only because private API allowed them: anything in
`WebKitPrivateDefinitions.h` with no public equivalent gets dropped, listed
in the PR description, one line of justification each. Do not chase pixel
parity via new private API — the point of this migration is to stop being
one macOS release from breakage.

## 5. Verification

- A `AIPreviewChat`/`AIWebKitPreviewMessageViewController` path already
  exists (style preview in prefs) — it exercises the full render pipeline
  headlessly-ish; keep it working at every step and use it as the harness.
- JS-side unit surface: the Template.html contract functions can be tested
  in isolation (load template in WKWebView in a test, drive commands,
  assert via postMessage echoes).
- Manual matrix in the cutover PR: 3+ message styles × (append, consecutive
  grouping, history context insert, replace-last, emoticons, file-transfer
  bubbles, /me actions) + the step-4 behavior list.
- Zero deprecation warnings from WebKit imports at the end.

## 6. Out of scope

- New message-view features (receipts/markers rendering per #28/#30 rides
  the same Template.html contract but ships with those issues).
- Message style format changes/xtras compatibility policy beyond parity.
- Dropping the style engine for native rendering (a different, larger
  debate).
