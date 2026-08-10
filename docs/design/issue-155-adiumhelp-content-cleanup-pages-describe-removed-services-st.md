# Design: AdiumHelp content cleanup: pages describe removed services, stale 1.4 pointers

- **Issue:** [#155 — AdiumHelp content cleanup: pages describe removed services, stale 1.4 pointers](../../../../issues/155)
- **Status:** Proposed

## 1. Summary

The shipped Help book (`AdiumHelp/`) was swept for branding (issue #122 s.2) — all display text now reads AdiumY, filenames and internal resource paths intentionally kept. That sweep was mechanical; the book still ships **content** that no longer matches what AdiumY is:

### Remove / re-author pages describing removed services
These pages exist in the book but describe services removed in the 2.0 clean break:

- `pgs/ServiceInformation-TwitterSupport.html`, `pgs/Accounts-Twitter.html` — Twitter plugin removed
- `pgs/Miscellaneous-AVSkypeSupport.html` — video chat / webcam glue removed
- `pgs/Accounts-AIM.html`, `pgs/AdvancedFeatures-AIM-DirectConnect.html`, `pgs/AdvancedFeatures-AIM-SearchForBuddyByEmail.html`, `pgs/Troubleshooting-ICQTextEncoding.html`, and any page under the removed OSCAR/MobileMe/GTalk/LiveJournal/Gadu-Gadu/GroupWise/Sametime/Zephyr protocols (AIM is mentioned across ~26 pages, ICQ ~14)

### Stale pointers
- Root page `AdiumHelp/AdiumHelp.html` still links "Check out great new features." → `pgs/WhatsNew1.4.html` (upstream 1.4 release notes; the forks first release is 2.0)
- `pgs/AdiumDocumentation.html` TOC lists the removed-service pages

### Rebuild
- Regenerate the pre-built `AdiumHelp/AdiumHelp.helpindex` after pruning

Branding is done; this is content accuracy. Re-author or prune to match the supported protocol set (XMPP, IRC, SIMPLE).

## 2. Approach

_To be filled in before implementation._

## 3. Verification

- [ ] Verify fix/feature works as described

