# Design: WebKit → WKWebView transition (as-built)

- **Status:** Implemented (message view landed in `40209d97`; cleanup + AMPurple form completed 2026-08)
- **Original proposal:** `issue-9-wkwebview-migration.md` (proposed a staged per-PR cutover; the actual code already contained a live WKWebView controller, so the remaining work was finishing the cleanup)

## 1. Why

`WebView` has been deprecated since macOS 10.14, and the plugin leaned on private WebKit API (`WebKitPrivateDefinitions.h`, `AIWebKitDelegate`, `ESWebFrameViewAdditions`) that breaks every OS release. `WKWebView` is the only supported embeddable web view.

## 2. The architectural change

WebView ran in-process with **synchronous** DOM access (`DOMDocument`, `stringByEvaluatingJavaScript:` returning values inline). WKWebView runs content out-of-process:

- **ObjC → page:** one-way JS command stream via `evaluateJavaScript:completionHandler:`. The style template's `Template.html` already had this shape (`appendHTML`, `replaceLastMessage`, the `CoalescedHTML` queue) — the contract extended, it didn't change.
- **Page → ObjC:** `window.webkit.messageHandlers.adium.postMessage(...)` events (`WKScriptMessageHandler`).
- **Custom scheme:** `AIAdiumURLProtocol` (an `NSURLProtocol`, which WKWebView ignores) became `AIAdiumURLSchemeHandler` (`WKURLSchemeHandler`) for the `adium://` scheme serving style resources/avatars.

## 3. Changes made

1. **Live controller** `AIWebKitMessageViewWKController.{h,m}` instantiates and drives the WKWebView (committed in `40209d97`); `AIWebKitMessageViewPlugin` hands out this controller via `messageDisplayControllerForChat:withPlugin:`.
2. **Deleted the dead WebView-era files** and removed them from the target (~3000 lines):
   `AIWebKitMessageViewController`, `AIWebKitDelegate`, `ESWebView`, `AIAdiumURLProtocol`, `ESWebFrameViewAdditions`, `WebKitPrivateDefinitions.h`.
3. **Re-based the prefs-pane style preview** `AIWebKitPreviewMessageViewController` on the WK controller (its previous base class was deleted). An initial `WKUIDelegate` context-menu override was added then removed — see §4.
4. **Migrated the purple request-fields form** `AMPurpleRequestFieldsController` (+ nib): `WebView` → `WKWebView`; `WebPolicyDelegate` → `WKNavigationDelegate` (`decidePolicyForNavigationAction:`); the form POST body parsing preserved verbatim; `navigationDelegate` wired in code (the old nib outlets don't exist on WKWebView and would throw `setValue:forUndefinedKey:` at nib load).
5. **Cleaned imports** of the deleted classes across the plugin and `AIChat.m`; removed the last `WebView` references in source and the two stale `GeneralPreferences` nib metadata entries.

## 4. Known gap: context menus

`WKContextMenuElementInfo` and the `WKUIDelegate` context-menu family are **iOS-only** in the macOS SDK. macOS WKWebView has **no public** context-menu customization hook. The old WebView-era chat view had a rich per-message menu; that behavior has no public equivalent and was not preserved. The default WKWebView context menu now appears in the main chat and in the prefs preview. Recreating per-message menus would require private API or JS hit-testing events — tracked as a deliberate non-goal (per the original proposal's "do not chase pixel parity via private API"). Follow-ups are tracked in §6.

## 5. Verification

- `xcodebuild -scheme "Adium - Debug" -configuration Debug` → exit 0, **zero warnings, zero errors** (forced rebuild).
- `git grep -l "WebKit/WebView.h\|DOMDocument\|stringByEvaluatingJavaScript"` → no hits in first-party source.
- Form dialog behavior unchanged: HTML generated as before; only the renderer and the navigation policy callback swapped.

## 6. Follow-ups

Gaps from this transition are tracked as GitHub issues:

- **#119** — chat message view lost its custom context menu after the WKWebView migration (macOS WKWebView has no public context-menu hook; see §4).
- **#120** — the HTML-paste image-loading guard relies on the deprecated `NSWebResourceLoadDelegateDocumentOption` WebView machinery.
- **#121** — stale `WebView` designer metadata remains in the `GeneralPreferences` nibs.
