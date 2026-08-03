# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- New entries go here

## [2.0.0] - 2026-08-03

### Added
- XEP-0352: Client State Indication for XMPP (Jabber) — send `<active/>`/`<inactive/>` on app foreground/background
- XEP-0048: Bookmarks for XMPP (Jabber) — sync MUC bookmarks via Private XML Storage
- XEP-0402: PubSub Bookmarks for XMPP (Jabber) — PEP-based bookmarks with automatic sync on connect
- XEP-0393: Message Styling for XMPP (Jabber) — bold/italic/strikethrough/monospace/blockquote/preformatted text
- XEP-0184: Message Delivery Receipts for XMPP (Jabber) — received receipts with `<request/>`/`<received/>` stanzas
- XEP-0333: Chat Markers for XMPP (Jabber) — displayed/acknowledged/received/active message markers
- XEP-0280: Message Carbons for XMPP (Jabber) — synchronize messages across multiple devices for the same account
- EdDSA (Ed25519) appcast signing tooling: `generate_appcast`, `generate_keys`,
  `sign_update` CLI tools extracted from Sparkle 2.9.4 distribution
- `Utilities/README-appcast.md` documenting the release signing workflow
- Register 15 AdiumY file-type identifiers (UTIs) in the app Info.plist so
  AdiumY owns the `com.github.phaedrus1992.adiumy.*` document types (message
  styles, soundsets, emoticonsets, icons, plugins, logs, and more)
- Set an app category (social networking) in the app Info.plist

### Changed
- First release under the AdiumY identity at version 2.0 — the app menu,
  About box, Dock, Finder, UI strings, and documentation all use the new
  product name
- Lowercased the bundle identifiers into the `com.github.phaedrus1992.adiumy`
  namespace: the app is now `com.github.phaedrus1992.adiumy`, the framework
  `com.github.phaedrus1992.adiumy.framework`, and libpurple
  `com.github.phaedrus1992.adiumy.libpurple` (previously the mixed-case
  `...adiumY.Adium` / `.AdiumFramework` / `.AdiumPurple`)
- Renamed the framework from Adium.framework to AdiumY.framework and the
  libpurple framework product from AdiumLibpurple to AdiumYLibpurple
- Moved internal identifiers (dispatch queues, Spotlight importer) onto the
  AdiumY namespace; legacy `im.adium.*` message-style identifiers remain only
  as migration-map keys so existing styles resolve correctly
- Fixed the Spotlight importer's bundle identifier typo ("spotlightImpoter")
- Kept "The Adium Team, 2005-2008" upstream copyright attribution, noted as an
  AdiumY fork
- Moved the app cache directory to `~/Library/Caches/AdiumY`
- Renamed the debug log directory to `~/Library/Logs/AdiumY Debug`
- Purple Service now only supports XMPP (Jabber), IRC, and SIMPLE protocols
- Build system: removed reference to libmeanwhile and json-glib in Xcode project
- Vendored Sparkle framework updated from 1.17.0 to 2.9.4
- Migrate update checker from Sparkle 1.x SUUpdater to Sparkle 2.x
  SPUStandardUpdaterController and SPUUpdaterDelegate
- Remove SUStatusChecker delegate conformance from AICrashReporter (removed in
  Sparkle 2.x — version comparison handled by Sparkle delegate API)

### Removed
- Dead protocol services: AIM/ICQ/OSCAR, MobileMe/.Mac, GTalk, LiveJournal,
  Gadu-Gadu, Novell/GroupWise, Sametime/Meanwhile, Zephyr
- Twitter Plugin (targets long-dead REST API v1.0, bundled STTwitter abandoned)
- Image Uploading Plugin (ImageShack/Imgur anonymous APIs, targets dead services)
- Video Chat Interface + Purple Service video/webcam glue (GStreamer/farstream
  scaffolding that never worked on macOS)
- libmeanwhile.framework and json-glib dependencies from build
- `Utilities/AppcastReplaceItem.py` (Python 2, md5Sum-based signing, dead
  signing URLs — replaced by Sparkle 2 EdDSA CLI tools)

### Fixed
- Message view: live user-icon updates restored in the WKWebView renderer —
  setting or changing a contact's icon now updates already-rendered messages
  without reopening the chat
- Message view: date separators restored in chat history — messages from a
  prior day again get a separator when a chat is opened on history
- Message view: topic changes render through the message style's topic template
  instead of injected raw HTML
- Message view: right-click context menu restored in the WKWebView renderer —
  the contact/group-chat menu (Open/Save Image, Clear Display) returns and pops
  at the cursor; Save Image As is offered for local image files
- Message view: topic text and content messages now render through the same
  filter, so styled topic text matches message rendering
- About window: auto-scrolling credits no longer jump to the top when the text
  has no enclosing scroll view

[Unreleased]: https://github.com/phaedrus1992/AdiumY/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/phaedrus1992/AdiumY/releases/tag/v2.0.0
