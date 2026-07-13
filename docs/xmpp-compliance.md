# XMPP Compliance Matrix

Last audited against: **XEP-0479 v0.1.0 (2023-05-04)** — XMPP Compliance Suites 2023
Base client: **libpurple 2.14.14** (vendored, with fork patches applied)
AdiumY fork commit: `main@311afb5f` (2026-07-12)

## Legend

| Column | Meaning |
|--------|---------|
| **Status** | `yes` = shipped, `partial` = exists but gated/incomplete, `no` = not implemented |
| **Level** | `R` = Required by suite, `A` = Advanced tier, `O` = Optional (outside suite) |
| **Issue** | Tracking issue number for gaps or planned improvements |

## Compliance Suites (XEP-0479 2023)

### Core Client — Advanced

| XEP/Norm | Name | Level | Status | Location | Issue |
|----------|------|-------|--------|----------|-------|
| RFC 6120 | XMPP Core | R | yes | libpurple `libxmpp.c`, `parser.c`, `jabber.c` | — |
| XEP-0368 | Direct TLS (XMPP over HTTPS) | R | **no** | — | [#31](https://github.com/phaedrus1992/adium/issues/31) |
| XEP-0030 | Service Discovery | R | yes | libpurple `disco.c`; Adium disco browser in `AMPurpleJabberNode.m` | — |
| XEP-0115 | Entity Capabilities | R | yes | libpurple `caps.c` | — |
| XEP-0163 | PEP (Personal Eventing Protocol) | R | yes | libpurple `pep.c` | — |

### IM Client — Required

| XEP/Norm | Name | Level | Status | Location | Issue |
|----------|------|-------|--------|----------|-------|
| RFC 6121 | XMPP IM | R | yes | libpurple `roster.c`, `presence.c`, `message.c` | — |
| XEP-0245 | /me Command | R | yes | libpurple `message.c` (action body handling, send via `serv_got_im` with flag) | — |
| XEP-0054 | vcard-temp | R | yes | libpurple `buddy.c` (92 references); Adium profile UI | — |
| XEP-0084 | User Avatar | R | yes | libpurple `useravatar.c` (v1.1); Adium avatar display | — |
| XEP-0280 | Message Carbons | R | yes | `Plugins/Purple Service/libpurple_extensions/carbons.c` (fork) | — |
| XEP-0191 | Simple Blocking | R | yes | libpurple `NS_SIMPLE_BLOCKING` in `namespaces.h`; IQ handler | — |
| XEP-0045 | Multi-User Chat | R | yes | libpurple `chat.c`; Adium group chat UI | — |

### IM Client — Advanced

| XEP/Norm | Name | Level | Status | Location | Issue |
|----------|------|-------|--------|----------|-------|
| XEP-0048 | Bookmarks | A | **no** | — | [#104](https://github.com/phaedrus1992/AdiumY/issues/104) (needed for Advanced Group Chat) |
| XEP-0313 | Message Archive Management | A | yes | `Plugins/Purple Service/AMPurpleJabberMAM.m` (fork) | — |
| XEP-0402 | PubSub Bookmarks | A | **no** | — | [#105](https://github.com/phaedrus1992/AdiumY/issues/105) (PEP-based, supersedes XEP-0048 v1) |
| XEP-0198 | Stream Management | A | yes | libpurple `stream_management.c` | — |
| XEP-0363 | HTTP File Upload | A | yes | `Plugins/Purple Service/AMPurpleJabberHTTPUpload.h/m` (fork) | — |

### Mobile Client — Required

| XEP/Norm | Name | Level | Status | Location | Issue |
|----------|------|-------|--------|----------|-------|
| (Core requirements) | — | R | yes | — | — |
| XEP-0198 | Stream Management | R | yes | libpurple `stream_management.c` | — |
| XEP-0352 | Client State Indication | R | **no** | — | [#103](https://github.com/phaedrus1992/AdiumY/issues/103) |

## Other XEPs Present in the Codebase

XEPs that are implemented but not required by any 2023 compliance suite.

| XEP | Name | Status | Location | Notes |
|-----|------|--------|----------|-------|
| 0012 / 0256 | Last Activity | yes | libpurple `iq.c` (jabber_iq_last_parse) | Also last activity in presence |
| 0047 | In-Band Bytestreams | yes | libpurple `ibb.c` | |
| 0050 | Ad-Hoc Commands | yes | libpurple `adhoccommands.c`; Adium `AMPurpleJabberAdHocCommand.m/Server.m/Ping.m` | |
| 0065 | SOCKS5 Bytestreams | yes | libpurple `si.c`, bytestreams | |
| 0066 | Out of Band Data | yes | libpurple `oob.c` | Both IQ and X data |
| 0071 | XHTML-IM | yes | libpurple `NS_XHTML_IM` | **Deprecated upstream** — successor is XEP-0393 Message Styling |
| 0085 | Chat State Notifications | yes | libpurple `NS_CHAT_STATES`; Adium typing indicators | |
| 0096 | SI File Transfer | yes | libpurple `si.c` | Profile for file transfer |
| 0107 | User Mood | yes | libpurple `usermood.c` (uses PEP) | |
| 0118 | User Tune | yes | libpurple `usertune.c` (uses PEP) | |
| 0124 / 0206 | BOSH / XMPP over BOSH | yes | libpurple `bosh.c` | |
| 0172 | User Nickname | yes | libpurple `usernick.c` (uses PEP) | |
| 0184 | Message Delivery Receipts | partial | libpurple patches (`receipt.c/h` in `Dependencies/patches/`) | Patches exist for libpurple but no Adium-level UI for displaying receipts. [Issue #28](https://github.com/phaedrus1992/adium/issues/28) |
| 0199 | XMPP Ping | yes | libpurple `ping.c`; Adium `AMPurpleJabberAdHocPing.m` | |
| 0202 | Entity Time | yes | libpurple `NS_ENTITY_TIME` | |
| 0203 | Delayed Delivery | yes | libpurple `NS_DELAYED_DELIVERY` | |
| 0224 | Attention | yes | libpurple `NS_ATTENTION` | |
| 0231 | Bits of Binary | yes | libpurple `NS_BOB` | |
| 0237 | Roster Versioning | yes | libpurple `NS_ROSTER_VERSIONING` | |
| 0264 | File Transfer Thumbnails | yes | libpurple `NS_THUMBS` | |
| 0308 | Message Correction | yes | `Plugins/Purple Service/AMPurpleJabberCorrection.h/m` (fork) | |
| 0333 | Chat Markers | partial | libpurple patches (`chatmarker.c/h` in `Dependencies/patches/`) | Patches exist for libpurple but no Adium-level UI. [Issue #30](https://github.com/phaedrus1992/adium/issues/30) |

## Missing XEPs (not in compliance suites)

These are commonly expected extensions that AdiumY does not yet support.

| XEP | Name | Notes | Issue |
|-----|------|-------|-------|
| 0384 | OMEMO Encryption | Requires signal protocol library, key management UI | [#27](https://github.com/phaedrus1992/adium/issues/27) |
| 0393 | Message Styling | Successor to XEP-0071 XHTML-IM; modern rich text | [#106](https://github.com/phaedrus1992/AdiumY/issues/106) |
| 0380 | Explicit Message Encryption | OMEMO dependency | Not yet filed |
| 0420 | SCE (Stanza Content Encryption) | OMEMO dependency | Not yet filed |
| 0385 | Stateless Media Sharing | Media sharing via HTTP | Not yet filed |
| 0392 | Consistent Color Generation | Color for unassociated entities | Not yet filed |
| 0433 | Channel Search | MUC discovery | Not yet filed |

## SASL / Authentication

| Mechanism | Status | Location | Notes |
|-----------|--------|----------|-------|
| PLAIN | yes | libpurple `auth_plain.c` | Always available |
| DIGEST-MD5 | yes | libpurple `auth_digest_md5.c` | |
| SCRAM-SHA-1 | yes | libpurple `auth_scram.c` | SHA-1 only in the `hashes[]` array |
| SCRAM-SHA-256 | **no** | — | hash not registered in `auth_scram.c`. [Issue #32](https://github.com/phaedrus1992/adium/issues/32) |
| SCRAM-SHA-512 | **no** | — | |
| GSSAPI | yes | libpurple `auth_cyrus.c` | Via Cyrus SASL library (optional) |
| EXTERNAL | no | — | Client certificate auth |
| SASL2 (XEP-0388) | **no** | — | Modern SASL framework |

## Transport Security

| Feature | Status | Notes |
|---------|--------|-------|
| STARTTLS (NS_XMPP_TLS) | yes | libpurple built-in |
| Direct TLS (XEP-0368) | **no** | |
| Certificate verification | yes | libpurple + Adium cert trust UI |

## How to Re-Audit

1. **Fetch the current compliance suites.** Check [XEP-0479 on xmpp.org](https://xmpp.org/extensions/xep-0479.html) for the latest year's suites. The XMPP Standards Foundation publishes a new revision each year.
2. **Diff the row set.** Compare the "Compliance Suites" tables above against the new suites. Add rows for any new requirements; remove any that were dropped.
3. **Verify each `yes` row.** For each XEP we claim to support, confirm the namespace string is present in the codebase (grep `libpurple/protocols/jabber/` for the namespace, and check `Plugins/Purple Service/` for any fork-added glue). Verify the feature is actually advertised in disco#info by checking `jabber_add_feature()` calls.
4. **Verify each `no` row.** For each unsupported required XEP, confirm there is still no code that registers its namespace. If any turns up, update the matrix and file a correction.
5. **SASL mechanisms.** Check `auth_scram.c` for the `hashes[]` array — it lists which SCRAM hashes are compiled in. New hashes require adding a `JabberScramHash` entry and linking the corresponding NSS/OpenSSL digest function.
6. **Update the header lines** at the top of this file: bump the XEP-0479 revision and libpurple version.

## Verified Gaps Requiring Issues

The following compliance requirements are not met and need tracking issues if they don't already have one:

| Gap | Has Issue? |
|-----|-----------|
| XEP-0368 Direct TLS | [#31](https://github.com/phaedrus1992/adium/issues/31) |
| XEP-0352 Client State Indication | [#103](https://github.com/phaedrus1992/AdiumY/issues/103) |
| XEP-0048 Bookmarks | [#104](https://github.com/phaedrus1992/AdiumY/issues/104) |
| XEP-0402 PubSub Bookmarks | [#105](https://github.com/phaedrus1992/AdiumY/issues/105) |
| SCRAM-SHA-256+ / SASL2 | [#32](https://github.com/phaedrus1992/adium/issues/32) |
| XEP-0393 Message Styling | [#106](https://github.com/phaedrus1992/AdiumY/issues/106) |
