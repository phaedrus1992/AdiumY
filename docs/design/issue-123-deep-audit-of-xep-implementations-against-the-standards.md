# Design: Deep audit of XEP implementations against the standards

- **Issue:** [#123 — Deep audit of XEP implementations against the standards](../../../../issues/123)
- **Status:** Proposed

## 1. Summary

# Deep audit of XEP implementations against the standards

**Area:** `Plugins/Purple Service/` (libpurple), any XMPP transport code

## Summary

Not just a list of which XEPs this codebase claims to implement. For every
XEP we implement, audit **the actual implemented code** against the full
standard and confirm:

1. **Full-standard coverage** — every REQUIRED element, attribute, flow, and
   error path in the XEP is present in the implementation, not just the happy
   path. Record each XEP's conformance level (Core/Full/partial) and what is
   missing.
2. **Test coverage** — each implemented part has tests exercising it:
   serialization/parsing round-trips, required-flow execution, and the
   XEP-defined error cases. Flag any implemented feature with zero tests.

## Deliverables

- A durable matrix: XEP -> conformance level -> parts implemented -> parts
  missing -> test coverage -> gaps
- For each gap: either fix it or file a follow-up issue per gap
- Publish the matrix in the repo so it stays current

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

