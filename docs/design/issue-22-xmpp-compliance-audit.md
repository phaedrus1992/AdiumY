# Design: XMPP compliance audit (tracking)

- **Issue:** [#22 — XMPP compliance audit (tracking)](../../../../issues/22)
- **Status:** Proposed
- **Scope:** new `docs/xmpp-compliance.md` (the deliverable), no product code changes

## 1. Problem

Issue #22 is the umbrella over the XEP gap issues (#23, #24, #26, #27, #28,
#29, #30). Its own actionable work is: **verify** the claimed have/missing
lists against the actual code, **measure** against the current XMPP Compliance
Suites (XEP-0479 and its successor revisions), and keep the result somewhere
honest and maintainable — a checked-in matrix, not an issue comment that rots.

## 2. Deliverable

`docs/xmpp-compliance.md` containing:

1. A table: XEP number, name, compliance-suite category (Core / IM / Mobile /
   A/V), status (`yes` / `partial` / `no`), where it's implemented (libpurple
   core vs `Plugins/Purple Service/` glue, with file references), and the
   tracking issue for gaps.
2. A short "how to re-audit" section (the method below) so the next update
   doesn't start from scratch.
3. A "last audited against" line naming the compliance-suite XEP revision and
   the libpurple version (currently 2.14.14).

## 3. Audit method (for the implementer)

### 3.1 Establish the target list

Fetch the current XMPP Compliance Suites (XEP-0479; check xmpp.org for
whichever year's suite has superseded it) and extract the Core Client and IM
Client requirement lists (Advanced tier). Ignore server-only rows. That list —
not the issue body — is the row set for the matrix.

### 3.2 Verify each claimed "have"

The issue body claims: 0004, 0012/0256, 0030, 0045, 0047, 0050/0146, 0065,
0071, 0084, 0085, 0096, 0107, 0115, 0118, 0124/0206, 0191, 0199, 0202, 0203,
0224, 0231, 0237, 0264, plus Adium's disco browser and XML console. For each:

- **libpurple side:** search the vendored prpl source — unpack
  `Dependencies/vendor/pidgin-2.14.14.tar.bz2` and grep
  `libpurple/protocols/jabber/` for the XEP's namespace string (namespaces,
  not XEP numbers, are what the code contains — e.g. `http://jabber.org/protocol/disco#info`,
  `urn:xmpp:ping`). A namespace registered in `jabber_add_feature` /
  `jabber_disco_*` counts as advertised; confirm there's also handling code.
- **Adium side:** `rg` the namespace in `Plugins/Purple Service/` (e.g. the
  ad-hoc commands implementation is `AMPurpleJabberAdHoc*`).
- Record `partial` where support exists but is off by default, send-only,
  receive-only, or gated on dead UI. Cite file:line for every `yes`/`partial`.

### 3.3 Verify each claimed "missing"

For 0184, 0198, 0280, 0308, 0313, 0333, 0363, 0368, 0384 and "modern SASL"
(SASL2/0388, channel binding): grep both the vendored libpurple and
`Plugins/Purple Service/` for the namespace. Expected result is no hits; if
anything turns up, the corresponding gap issue gets a correcting comment.
Confirm each missing row links to its issue (#23 carbons, #24 MAM, #26 upload,
#27 OMEMO, #28 receipts, #29 correction, #30 markers; stream management 0198
and direct TLS 0368 have **no issue yet — file them** as part of this work,
per the no-gap-left-silent rule).

### 3.4 Live cross-check (cheap, worth it)

Connect a build to a modern server (ejabberd/Prosody demo account) alongside a
reference client, and compare Adium's advertised disco#info (visible in
Adium's own XML console: send a disco#info iq to your own full JID from the
other client) against the matrix's `yes` rows. Catches "code exists but
feature never advertised" mismatches that grepping misses.

### 3.5 Notes to carry into the matrix

- XHTML-IM (0071) is deprecated upstream; the matrix should mark it
  `yes (deprecated — successor is Message Styling 0393, no issue yet: file one)`.
- The suites revise yearly; the doc's "how to re-audit" section tells the next
  person to diff the new suite's row set against the table, not redo §3.2.

## 4. Verification of this task itself

- `docs/xmpp-compliance.md` exists; every `yes`/`partial` row has a file:line
  citation; every `no` row has an issue link.
- New issues filed for 0198, 0368, 0393 (and anything else the current suite
  requires that has no issue), each referencing the matrix.
- Issue #22's body updated to point at the matrix as the source of truth.

## 5. Out of scope

- Implementing any XEP (each has/gets its own issue + design doc).
- Auditing non-XMPP protocols.
