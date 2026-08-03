[AdiumY](https://github.com/phaedrus1992/AdiumY)
================================================

## About AdiumY

AdiumY is a fork of [Adium](https://github.com/adium/adium), a free and open
source instant messaging application for macOS, written using Cocoa and
released under the [GNU GPL](https://www.gnu.org/licenses/licenses.html#GPL).
Based on the [libpurple](https://developer.pidgin.im/wiki/WhatIsLibpurple)
protocol library, AdiumY connects to messaging accounts and chats with other
people using those services.

This fork starts a fresh 2.0 version line: it removes the dead protocols and
services upstream accumulated, renames the product to AdiumY, and re-registers
its file types and identifiers under the `com.github.phaedrus1992.adiumy`
namespace. See the [CHANGELOG](CHANGELOG.md) for the full list of changes.

## Notable Features

* Open source — everyone can see how AdiumY works and help improve it
* XMPP (Jabber), IRC, and SIMPLE messaging via libpurple
* A delightful UI with tabbed chat windows
* macOS integration, including Address Book integration and a themeable
  WebKit Message View
* Combined Contacts: merge your contacts so each represents a person, not an
  account
* A sophisticated events system (including Growl notifications)
* OTR encryption
* File transfer
* Xtras and many other customization options
* A beautiful icon, the "Adiumy" duck
* Localized into more than 30 languages

## System Requirements

* **macOS 12.0 or later** (Monterey)
* Intel or Apple Silicon Mac

## Development

* **Code style**: `.clang-format` (LLVM-based, tabs, 4-char indent, 120 cols,
  Allman brace style). Run `make format` to reformat, `make format-check` for
  CI-style validation. Requires `clang-format` 22+ (`brew install clang-format`).
* **Coverage gate**: `make coverage-check` enforces a minimum 50% line coverage
  on production targets (configurable via `COVERAGE_THRESHOLD`). Coverage
  instrumentation is enabled for Debug builds.
* **CI**: GitHub Actions enforces both checks on every push.
* **Build**: Debug and Release schemes build via Xcode; see `Makefile` and
  `docs/` for details.

## Contributing

See `CLAUDE.md` and `docs/` for project conventions and workflow. Build, test,
and quality gates are described there.

## Contact

* Repository: <https://github.com/phaedrus1992/AdiumY>
* Report issues: <https://github.com/phaedrus1992/AdiumY/issues>
