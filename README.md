[AdiumY](https://github.com/phaedrus1992/adium)
===============================================

[![Adiumy](https://github.com/phaedrus1992/adiumy/images/logo.png)](https://github.com/phaedrus1992/adiumy/Adium_1.5.10.4.dmg)

[Download Adium 1.5.10.4](https://github.com/phaedrus1992/adiumy/Adium_1.5.10.4.dmg)

## About AdiumY ##

AdiumY is a fork of [Adium](https://github.com/phaedrus1992/adiumy), a free and open source instant messaging application for [OS X](https://www.apple.com/osx/), written using OS X's Cocoa API, released under the [GNU GPL](https://www.gnu.org/licenses/licenses.html#GPL). Based on the [libpurple](https://developer.pidgin.im/wiki/WhatIsLibpurple) protocol library, AdiumY can connect you to any number of messaging accounts on any combination of supported messaging services and then chat with other people using those services.

## Notable Features ##
* Open Source, so everyone can see how AdiumY works and help improve it.
* Support for a wide range of different Instant Messaging services (see the [full list](https://github.com/phaedrus1992/adiumy/help/pgs/Accounts-ListOfServices.html))
* A delightful UI
  * [Tabbed chat windows](https://github.com/phaedrus1992/adiumy/help/pgs/Messaging-TabbedMessaging.html)
* Mac OS X integration
	* [Address Book integration](https://github.com/phaedrus1992/adiumy/help/pgs/AdvancedFeatures-AddressBookIntegration.html)
	* [WebKit Message View](https://github.com/phaedrus1992/adiumy/help/pgs/Messaging-MessageView.html):  Theme your chat windows
* [Combined Contacts](https://github.com/phaedrus1992/adiumy/help/pgs/ContactList-CombiningContacts.html): Merge your contacts so that each one represents a person, not an account
* A sophisticated events system (including [Growl notifications](https://github.com/phaedrus1992/adiumy/help/pgs/AdvancedFeatures-GrowlSupport.html))
* [OTR Encryption](https://github.com/phaedrus1992/adiumy/help/pgs/AdvancedFeatures-OTREncryption.html)
* [File Transfer](https://github.com/phaedrus1992/adiumy/help/pgs/AdvancedFeatures-FileTransfer.html)
* [Xtras](https://github.com/phaedrus1992/adiumy/help/pgs/AdvancedFeatures-AdiumYExtras.html) and many, many other customization options
* A beautiful icon, the "Adiumy" duck
* Translations: AdiumY speaks 27 different languages

## Development Tooling ##

* **Code style**: `.clang-format` (LLVM-based, tabs, 4-char indent, 120 cols, Allman brace style).
  Run `make format` to reformat, `make format-check` for CI-style validation.
  Requires `clang-format` 22+ (`brew install clang-format`).
* **Coverage gate**: `make coverage-check` enforces a minimum 50% line coverage
  on production targets (configurable via `COVERAGE_THRESHOLD`). Coverage
  instrumentation is enabled for Debug builds.
* **CI**: GitHub Actions enforces both checks on every push.

## System requirements ##
- **Adium 1.5 or later**: Mac OS X 10.6.8 or newer, an Apple-branded Macintosh computer
- [Adium 1.4.5](https://github.com/phaedrus1992/adiumy/Adium_1.4.5.dmg): Mac OS X 10.5.8
- [Adium 1.3.10](https://github.com/phaedrus1992/adiumy/Adium_1.3.10.dmg): Mac OS X 10.4
- [Adium 1.0.6](https://github.com/phaedrus1992/adiumy/Adium_1.0.6.dmg): Mac OS X 10.3.9
- [Adium X 0.89.1](https://github.com/phaedrus1992/adiumy/AdiumX_0.89.1.dmg): Mac OS X 10.2.x and older

Adium X 0.88 up to Adium 1.4.5 are Universal applications which run natively on both PowerPC- and Intel-based Macintosh computers. Adium 1.5 and up require an Intel based computer.

## Contributing ##
* [Development information](https://web.archive.org/web/20200915230142/https://github.com/phaedrus1992/adiumy/wiki/Development)  
* [Contribute code](https://web.archive.org/web/20200923043011/https://github.com/phaedrus1992/adiumy/wiki/ContributingCode)
* [User Interface Guidelines](https://web.archive.org/web/20200923043702/https://github.com/phaedrus1992/adiumy/wiki/UIDesignGuidelines)
* [Coding Style Guidelines](https://web.archive.org/web/20170306235100/https://github.com/phaedrus1992/adiumy/wiki/CodingStyle)
* [Coding Tips and Tricks](https://web.archive.org/web/20200923044150/https://github.com/phaedrus1992/adiumy/wiki/DevelopmentTipsAndTricks)

## Adium Contact information ##
 * https://github.com/phaedrus1992/adiumy/
 * feedback@adiumyextras.com
