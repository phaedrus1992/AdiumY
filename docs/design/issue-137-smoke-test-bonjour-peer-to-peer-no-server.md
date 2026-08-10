# Design: Smoke test: Bonjour (peer-to-peer, no server)

- **Issue:** [#137 — Smoke test: Bonjour (peer-to-peer, no server)](../../../../issues/137)
- **Status:** Proposed

## 1. Summary

# Smoke test: Bonjour (self-contained, no server)

Part of epic #133. Unique among the four transports: **Bonjour needs no server at all.** It's Adium's own peer-to-peer EZV protocol advertised via mDNS as `_presence._tcp` (see `Plugins/Bonjour/libezv/Private Classes/AWEzvContactManagerRendezvous.m`), so two Adium instances on the same LAN (or same host, via loopback) discover each other directly.

## Plan

1. **Two peers** — launch two throwaway Adium profiles pointing at the same host/loopback:
   - Peer A: Bonjour account with a distinctive display name (`smoke-a`).
   - Peer B: Bonjour account (`smoke-b`).
   (Peer B could later be a scripted mDNS + EZV stub, but two real instances is the honest first pass.)
2. **Discovery assertion** — wait for each peer's contact list to show the other under the Bonjour group (`addRemoteGroupName:@"Bonjour"` in `AWBonjourAccount.m`). Assert within a timeout.
3. **Message assertion** — peer A sends a marker message; peer B receives and displays it; assert both directions.
4. **Teardown** — quit both instances, delete both temp profiles.
5. **Repeatable** — `scripts/smoke/bonjour.sh`, non-zero exit on failed discovery or message.

## Caveat — loopback discovery

mDNS/bonjour service discovery generally works over loopback on macOS (`dns-sd` browses `_presence._tcp`), but the rendezvous manager may filter by interface. First task in this sub-issue: verify two instances on one host discover each other via loopback; if the OS suppresses loopback advertisement, fall back to two hosts on a shared LAN (or two VMs on one virtual network) and document the requirement.

## Out of scope (this iteration)

File transfer (jabber:iq:oob paths in `AWEzvContact.m`), event notifications (`jabber:x:event`), chat state — presence + 1:1 message only.

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

