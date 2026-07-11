# Design: XEP-0384 OMEMO encryption

- **Issue:** [#27 — XEP-0384: OMEMO encryption](../../../../issues/27)
- **Status:** Proposed
- **Depends on:** carbons (#23) strongly recommended first (OMEMO without carbons gives multi-device crypto on a client that can't see its own multi-device traffic). HTTP upload (#26) needed later for encrypted media (XEP-0454), not for v1.
- **Scope:** new C purple plugin (ported `lurch`) + new dependencies (libsignal-protocol-c, sqlite is system), `Plugins/Purple Service/` trust UI, `Source/AdiumOTREncryption`-adjacent content-controller integration

## 1. Problem

E2E today is OTR only (`Source/AdiumOTREncryption.m` + `ESOTR*` windows +
`Plugins/Secure Messaging/` lock UI, over vendored libotr 4.1.1). OTR doesn't
survive multi-device or offline delivery and no modern client ships it. OMEMO
(XEP-0384, Signal double-ratchet over PEP-published device keys) is what
Conversations/Monal/Gajim/Dino speak.

## 2. Strategy: port `lurch`, keep Adium work UI-focused

`lurch` (github.com/gkdr/lurch) is the proven libpurple-2 OMEMO plugin:
C, built on `libsignal-protocol-c` + its own `axc`/`libomemo` helper libs,
uses the same `jabber-receiving/sending-xmlnode` signal surface as the other
XEP designs in `docs/design/`. Writing OMEMO from scratch (double-ratchet
session management, PEP device lists, prekey bundles) is months; porting
lurch turns this into a build/integration/UI project.

**License:** lurch and libsignal-protocol-c are GPLv3. Adium is GPLv2
**or later** (`License.txt:301-302`), so the combination is distributable
(effectively under GPLv3). Record this in the PR; no blocker.

### Phasing (each lands separately)

**Phase A — dependencies.** Extend `Dependencies/` with build phases for
`libsignal-protocol-c`, `libomemo`, `axc` (vendored tarballs via
`vendor-fetch.sh`, phases modeled on `build-phases/build-gcrypt.sh` — the
pipeline conventions are established; see also
`docs/design/issue-55-dependency-frameworks.md`). All three are small CMake/
make C libraries; universal build per repo convention. lurch's message store
is sqlite — use the system `libsqlite3`, do not vendor sqlite.

**Phase B — lurch port, headless.** `lurch.c` (+ its helpers) into
`Plugins/Purple Service/libpurple_extensions/`, compiled into Purple Service
and registered like the carbons plugin (#23 doc §3.2 — do carbons first, it
debugs this exact registration path at 1/10 the size). Point lurch's key/db
path at `~/Library/Application Support/Adium 2.0/OMEMO/<account>/`. At the
end of B: OMEMO works via lurch's built-in `/lurch` conversation commands
only — functional, no Adium UI. Ship it behind default-off.

**Phase C — Adium encryption UI.** The real Adium work:

1. **Lock/menu integration.** `Plugins/Secure Messaging/
   ESSecureMessagingPlugin` drives the lock icon and Encryption menu from
   the content controller's encryption state. Add OMEMO as a second
   encryption provider alongside `AdiumOTREncryption`: per-chat mode
   (OMEMO/OTR/off). lurch exposes enable/disable per conversation via its
   command API — bridge menu actions to it, and reflect lurch's
   "topic"/state callbacks back into the chat's `securityDetails` so the
   existing lock UI just works.
2. **Trust management (the "real work" the issue names).** lurch's model is
   BTBV ("blind trust before verification") with fingerprint listing via
   commands. v1 UI: a per-contact device list (device id + fingerprint hex,
   trust toggle) reachable from the Encryption menu — model the window on
   `ESOTRFingerprintDetailsWindowController` (same shape of problem, code to
   crib from, `Source/ESOTR*`). BTBV default matches Conversations and keeps
   the UX survivable. QR/SAS verification: out of scope.
3. **Own-device management:** list + revoke own published devices (PEP
   devicelist cleanup) in the same window.

**Phase D — interop hardening.** Carbons of OMEMO messages decrypt (needs
#23 + lurch handles it, verify), MAM-fetched OMEMO messages show the
"encrypted message" placeholder gracefully (#24 §5 already accepts this),
group chat OMEMO explicitly **disabled** in v1.

## 3. Key risks

- **lurch upstream is lightly maintained.** Vendor at a pinned commit,
  carry patches in-tree (`Dependencies/` convention), expect to own it.
  Alternative rejected: waiting for libpurple 3's native OMEMO — different
  libpurple major, not on this fork's path.
- **OTR/OMEMO arbitration.** Two encryption layers racing on one chat is the
  classic port bug: make mode selection exclusive per chat in the content
  controller before enabling OMEMO by default anywhere.
- **Database/key loss = silent identity change** for contacts. Backup note in
  docs; the OMEMO dir must be included in whatever backup guidance exists.

## 4. Verification

- Phase A: deps build universal, `lipo -archs` both slices.
- Phase B: `/lurch` session with Conversations both directions; restart
  Adium, session resumes; second own-device sees messages (with #23).
- Phase C: lock icon reflects state; trust toggle blocks/unblocks a device
  (verify a *new* device of the contact prompts per BTBV); mode menu
  mutually exclusive with OTR.
- Unit tests where the seams allow: the ObjC bridge (menu state ↔ lurch
  command mapping, securityDetails population) with lurch faked at the
  command boundary. The crypto core is upstream-tested; don't re-test
  libsignal.

## 5. Out of scope

- Encrypted file transfer (XEP-0454/aesgcm) — follow-up after #26 + this.
- MUC OMEMO, QR-code verification, OTR removal (OTR stays until OMEMO has
  soaked a release).
