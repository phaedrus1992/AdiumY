# Design: Bonjour EZV: AppleSingle envelope can mask truncation of the #263 size check

- **Issue:** [#269 — Bonjour EZV: AppleSingle envelope can mask truncation of #263's size check](../../../../issues/269)
- **Status:** Implemented (sprint #272, PR #276)

## 1. Summary

Issue #263's truncation check compares `bytesReceived` (the wire byte count) against the
peer-declared `size` with a `<` comparison, deliberately so an AppleSingle-encoded body's envelope
(header + entry table + Finder info) does not false-positive a truncation. That leniency is a blind
spot: a truncated AppleSingle body can still satisfy `bytesReceived >= size` when the envelope
overhead alone pushes the wire count up to or past the declared size while the raw content is short.
The check must measure the raw content, not the wire bytes.

## Repro

1. A LAN peer advertises an incoming transfer declaring `<size>100</size>`.
2. It sends an AppleSingle body whose raw data fork is 80 bytes — on the wire, 26-byte header +
   12-byte entry + 80 = 118 bytes.
3. The old check sees `bytesReceived (118) >= size (100)` and accepts the transfer; the installed
   file is 80 bytes, silently short of the declared 100.

## Approach

- **Envelope accounting:** during `decodeAppleSingleAtPath:` accumulate the envelope overhead
  (`[data length] - dataForkLength`) into `appleSingleEnvelopeBytes`. `transferWasTruncated`
  compares `bytesReceived - appleSingleEnvelopeBytes` against `size`, so the raw data-fork length is
  what is measured.
- **Non-cross-checkable sizes:** a zero declared size (and, in the sibling XtrasInstaller gate, an
  unknown `NSURLResponseUnknownLength`) has no declared byte count to compare against — never fail
  on it. Documented in `transferWasTruncated`, consistent with #263.
- **Fail-closed drift guard:** if accumulated envelope overhead ever exceeds `bytesReceived`, the
  unsigned subtraction would wrap to a huge value and silently accept a truncated body. That drift is
  unreachable on the current decode path (each term is a subset of that file's received bytes), but
  the guard treats it as truncated so the gate fails closed rather than relying on the invariant.
- **Dual-fork preference:** a body carrying both a data fork and a resource fork must install the
  data fork — it is the content the transfer delivers and the check measures. Last-content-entry-wins
  would install a resource fork whose length the check never validated. A resource-fork-only body (no
  data fork) counts its whole content as envelope and can false-positive a truncation; that is
  pathological for EZV and fails loudly on untrusted data.

## Verification

- `transferWasTruncated` predicate unit tests: short-wire, envelope-masked truncation, envelope-aware
  completion, plain overrun, zero size, envelope-exceeds-received fail-closed.
- Decode end-to-end: truncated body fails the transfer and removes artifacts; complete body keeps the
  raw data fork; dual-fork `[DATA_FORK(80), RESOURCE_FORK(5)]` installs the 80-byte data fork.
- Mutation-tested: removing the drift guard, removing the data-fork preference, and widening the
  strict `<` each fail a targeted test.
