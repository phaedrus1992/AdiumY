# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Add a fastlane release pipeline that builds, Developer ID signs, notarizes
  and staples AdiumY, packages it as a disk image, and publishes it to GitHub
  Releases with a signed Sparkle appcast — releases can now be cut from CI on a
  `v*` tag instead of one maintainer's laptop
- Add "Save Image As" to the message-view context menu for remote images

### Changed
- Point the Sparkle update feed at
  `https://raw.githubusercontent.com/phaedrus1992/AdiumY/main/appcast.xml`;
  `SUFeedURL` was previously an empty string, so auto-update was linked but
  never configured

### Removed
- Remove the pre-fork release tooling in `Release/`. It drove mercurial, signed
  with a certificate belonging to another team, and depended on `mkalias`,
  `buildchlog`, and an `AdiumApplescriptRunner` build product that cannot run
  on any supported macOS

### Fixed
- Remove partial files and created folder trees when an incoming Bonjour file
  transfer fails or is cancelled, instead of leaving them on disk
- Escape special characters in Bonjour XML attribute values so a peer-supplied
  value cannot inject markup into the serialized tag
- Fix outgoing Bonjour folder transfers hanging when a file or folder nests
  deeper than 32 levels — the sender now caps its file list at the same depth
  the receiver enforces, so the download queue drains and the transfer completes
- Fix Bonjour folder transfers failing when a file or folder name contains
  non-ASCII characters — the folder XML is now sized by UTF-8 byte length
  instead of being truncated mid-tag
- Reject Bonjour XML nested past 32 levels from a peer instead of building a
  tree deep enough to overflow the stack when it is torn down
- Stop HTML paste from loading remote images embedded in pasted rich text — it
  no longer triggers a network request for those images
- Fix message-style preferences left over from the pre-rename AdiumY fork
  (`im.adium.*` style IDs) being ignored during preference migration — they now
  remap to the AdiumY bundle-ID namespace on next launch
- Reject non-image or oversized responses when saving a remote image from the
  message-view context menu, instead of writing the response body to disk
- Use only the remote file's leaf name as the default save name for incoming
  file transfers, falling back to "Untitled" for empty, `.`, `..`, `/`, or
  whitespace-only names
- Reject non-2xx HTTP responses before any bytes are written to disk for file
  downloads — a failed Xtra download is no longer auto-installed, and a failed
  Bonjour file transfer is no longer decoded or unpacked
- Report Bonjour file-transfer failures as "Failed" instead of "Cancelled by
  remote user" when the download errors on the receiver or sender side
- Reduce Bonjour file-transfer peer-supplied filenames to a single safe leaf —
  degenerate names (empty, ".", "..", whitespace) now fail the transfer instead
  of resolving to an unexpected path
- Ignore malformed (non-hex) permission flags from Bonjour file-transfer peers
  instead of applying garbage file permissions
- Use only a safe leaf name as the default when saving remote images from the
  message-view context menu, never a raw remote path
- Cap Bonjour file-transfer folder downloads at 32 nesting levels — a
  peer-supplied folder tree deeper than that is rejected instead of recursing
  without bound
- Unregister every notification observer the user-icon plugin registers when it
  uninstalls, instead of leaving them registered
- Unregister the user-icon plugin's toolbar item when it uninstalls, so no dead
  "Contact Icon" item is left in the chat window toolbar
- Remove the iTunes plugin's distributed and current-track observers, "Now
  Playing" status state, "Current iTunes Track" toolbar item, and trigger menu
  items when it uninstalls, so it leaves nothing behind
- Remove the error-message handler plugin's notification observer when it
  uninstalls, so it stops displaying error messages after removal
- Remove the appearance preferences plugin's status-icon-set notification
  observer when it uninstalls, so it stops reacting to icon-set changes after
  removal
- Fix the nudge-and-buzz and AppleScript-filters plugins leaving their
  outgoing-message content filters registered after uninstall
- Fix the nudge-and-buzz, secure-messaging, link-management, contact-info,
  contact-list-editor, logger, emoticon-menu, standard-toolbar, blocking,
  Safari-link, and AppleScript-filters plugins leaving their chat and
  contact-list toolbar items registered after uninstall
- Fix the auto-reply, status-changed-messages, account-list-preferences,
  contact-sort-selection, general-preferences, status-menu-item, and
  away-status-window plugins leaving notification observers registered after
  uninstall
- Fix the contact-list-contents plugin leaving its contact-list tooltip entry
  and contextual menu item registered after uninstall
- Fix the contact-sort-selection plugin leaving its sort controllers registered
  after uninstall, so the contact list keeps a working sort
- Fix the link-management, nudge-and-buzz, secure-messaging, add-bookmark,
  alias-support, chat-cycling, contact-info, contact-list-editor,
  contact-visibility-control, logger, detached-windows, URL-shortener,
  emoticon-menu, contact-counting-display, blocking, import, privacy-settings,
  and contact-sort-selection plugins leaving their menu items registered after
  uninstall
- Fix the contact-away, contact-idle, contact-online-since, contact-client,
  contact-serverside-display-name, contact-online-for, and contact-last-seen
  plugins leaving their contact-list tooltip entries registered after uninstall
- Remove the dock-name-overlay and contact-last-seen plugins' list-object
  observers when they uninstall, so the contact list stops reacting to their
  changes after removal
- Remove the chat-consolidation, new-message, join-chat, invite-to-chat, and
  edit-status-menu items five plugins register when they uninstall, instead of
  leaving dead menu entries that target a released plugin
- Unregister the status and advanced-status preference panes the edit-status-menu
  plugin registers when it uninstalls
- Unregister the status-menu plugin's list-object observer and remove its dock,
  status-menu, and account menu items when it uninstalls, so it leaves nothing
  registered
- Stop the idle plugin's repeating idle-update timer when it uninstalls or when
  the last tracked contact stops being idle, instead of letting it keep firing
- Drop the hide-accounts submenu delegate when the contact-visibility plugin
  uninstalls, so the menu cannot message a released plugin
- Remove the contact-alert action handlers the eleven alert plugins register
  when they uninstall, so an uninstalled plugin stops responding to alerts
- Fix a crash when every contact-alert action plugin has been uninstalled, since
  the default-action fallback no longer indexes an empty handler list
- Remove the account-menu items the account-menu-access plugin registers when it
  uninstalls
- Remove the appearance-preferences pane the appearance-preferences plugin
  registers when it uninstalls
- Drop the emoticon-menu and SCL-view plugins' submenu delegates when they
  uninstall, so their menus cannot message a released plugin
- Clear the Xtras-manager singleton when the Xtras plugin uninstalls, so it
  leaves no live reference behind
- Remove the contact-alert event handlers the error-message-handler,
  account-events, and nudge-and-buzz plugins register when they uninstall, so
  an uninstalled plugin stops firing its events
- Remove the preference panes the general-preferences, mention-event,
  URL-handler, account-list-preferences, global-events-preferences, and
  advanced-preferences plugins register when they uninstall, so an uninstalled
  plugin's panes leave the preferences window — advanced panes now actually
  unregister instead of silently staying registered
- Clear the message-context-display plugin's shared instance when it
  uninstalls, so it leaves no live reference behind
- Stop the account-events plugin's grouping timers when it uninstalls, so they
  stop firing into a released plugin
- Fix the contact-status-events plugin leaving its five per-contact status caches
  allocated after uninstall
- Unregister the dual-window interface plugin's interface controller and remove
  its advanced preference pane when it uninstalls
- Unregister the Bonjour plugin's Bonjour service when it uninstalls
- Unregister a service's statuses when it uninstalls, so they no longer remain
  selectable in the status menu
- Unregister the IRC, Simple, and Jabber services the purple-service plugin
  registers when it uninstalls
- Unregister the contact list controller the SCL-view plugin registers when it
  uninstalls, so the interface stops holding a released plugin as its contact
  list controller
- Cap Bonjour message-XML serialization at 32 nesting levels — a deeply nested
  peer-supplied message no longer crashes the app (stack overflow while
  serializing), instead of recursing without bound
- Remove the partially-created folder tree when a Bonjour folder download fails,
  so a failed download no longer leaves a partial tree at the chosen destination
- Fix a completed Bonjour file transfer being deleted by a late cancel or a stale
  error — once a transfer has fully received its files, cancelling it or a
  failure arriving afterwards leaves the received files on disk
- Fix Bonjour messages containing `&`, `<`, or `>` being escaped twice on the
  wire — a peer now receives the literal character instead of the double-escaped
  `&amp;amp;`

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
