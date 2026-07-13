# Task 2: XEP-0048 Bookmarks — Report

**Completed:** 2026-07-13
**Branch:** `feat/109-xmpp-bookmarks` (based on `feat/108-xmpp-compliance@68ae2944`)
**Issue:** [#104](https://github.com/phaedrus1992/AdiumY/issues/104)

## Implementation

### New Files

| File | Purpose |
|------|---------|
| `Plugins/Purple Service/AMPurpleJabberBookmarks.h` | Header declaring `AMPurpleJabberBookmarks : NSObject` with `initWithAccount:`, `retrieveBookmarks`, `storeBookmarksWithXML:` |
| `Plugins/Purple Service/AMPurpleJabberBookmarks.m` | Implementation -- MRC, follows CSI/Correction controller pattern |
| `UnitTests/TestAMPurpleJabberBookmarks.h` | Test header with 3 test methods |
| `UnitTests/TestAMPurpleJabberBookmarks.m` | Tests XML stanza construction for retrieve/store operations |

### Modified Files

| File | Change |
|------|--------|
| `Plugins/Purple Service/ESPurpleJabberAccount.h` | Added `@class AMPurpleJabberBookmarks;` and `AMPurpleJabberBookmarks *bookmarksController;` ivar |
| `Plugins/Purple Service/ESPurpleJabberAccount.m` | Added `bookmarksController` init block |
| `Adium.xcodeproj/project.pbxproj` | +22 lines across all 6 required sections |

## Architecture

### Controller Pattern

- **`+initialize`**: Registers `storage:bookmarks` feature via `jabber_add_feature()`
- **`initWithAccount:`**: Stores weak reference `_account`, connects `jabber-receiving-xmlnode` signal
- **`dealloc`**: Disconnects signal handle via `purple_signals_disconnect_by_handle`
- **C callback**: Uses `NSAutoreleasePool`, filters for IQ/result + `jabber:iq:private` + `storage:bookmarks`, parses `<conference>` elements into dictionaries, posts `AIBookmarksReceived` notification
- **`retrieveBookmarks`**: Sends IQ-get via `jabber_prpl_send_raw`
- **`storeBookmarksWithXML:`**: Sends IQ-set via `jabber_prpl_send_raw`

### XMPP Protocol

- **XEP-0048 v1**: `<storage xmlns='storage:bookmarks'>` with `<conference>` children
- **XEP-0049 Transport**: Private XML Storage via `jabber:iq:private` namespace
- **IQ-get**: Retrieves stored bookmarks from server
- **IQ-set**: Stores bookmarks on server

## Commit

```
feat: implement XEP-0048 Bookmarks (Private XML Storage) controller
```

## Build Integration

All 6 required pbxproj sections completed:
1. PBXBuildFile declarations (test .m, source .m, source .h)
2. PBXFileReference declarations (test .h, test .m, source .h, source .m)
3. PBXGroup (test group, source group)
4. Headers build phase
5. Sources build phase -- test target
6. Sources build phase -- main target
