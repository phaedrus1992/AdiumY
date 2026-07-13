# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- Dead protocol services: AIM/ICQ/OSCAR, MobileMe/.Mac, GTalk, LiveJournal,
  Gadu-Gadu, Novell/GroupWise, Sametime/Meanwhile, Zephyr
- Twitter Plugin (targets long-dead REST API v1.0, bundled STTwitter abandoned)
- Image Uploading Plugin (ImageShack/Imgur anonymous APIs, targets dead services)
- Video Chat Interface + Purple Service video/webcam glue (GStreamer/farstream
  scaffolding that never worked on macOS)
- libmeanwhile.framework and json-glib dependencies from build

### Added
- XEP-0184: Message Delivery Receipts for XMPP (Jabber) — received receipts with `<request/>`/`<received/>` stanzas
- XEP-0333: Chat Markers for XMPP (Jabber) — displayed/acknowledged/received/active message markers
- XEP-0280: Message Carbons for XMPP (Jabber) — synchronize messages across multiple devices for the same account
- EdDSA (Ed25519) appcast signing tooling: `generate_appcast`, `generate_keys`,
  `sign_update` CLI tools extracted from Sparkle 2.9.4 distribution
- `Utilities/README-appcast.md` documenting the release signing workflow

### Changed
- Renamed user-visible product name from "Adium" to "AdiumY" — affects app menu, About box, Dock, Finder, UI strings, README
- Purple Service now only supports XMPP (Jabber), IRC, and SIMPLE protocols
- Build system: removed reference to libmeanwhile and json-glib in Xcode project
- Vendored Sparkle framework updated from 1.17.0 to 2.9.4
- Migrate update checker from Sparkle 1.x SUUpdater to Sparkle 2.x
  SPUStandardUpdaterController and SPUUpdaterDelegate
- Remove SUStatusChecker delegate conformance from AICrashReporter (removed in
  Sparkle 2.x — version comparison handled by Sparkle delegate API)

### Removed
- `Utilities/AppcastReplaceItem.py` (Python 2, md5Sum-based signing, dead
  signing URLs — replaced by Sparkle 2 EdDSA CLI tools)
