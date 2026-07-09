# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed
- Dead protocol services: AIM/ICQ/OSCAR, MobileMe/.Mac, GTalk, LiveJournal,
  Gadu-Gadu, Novell/GroupWise, Sametime/Meanwhile, Zephyr
- libmeanwhile.framework and json-glib dependencies from build

### Changed
- Purple Service now only supports XMPP (Jabber), IRC, and SIMPLE protocols
- Build system: removed reference to libmeanwhile and json-glib in Xcode project
