# Design: Migrate AddressBook.framework to Contacts.framework

- **Issue:** [#11 — migrate AddressBook framework to Contacts](../../../../issues/11)
- **Status:** Proposed
- **Scope:** every `AB*` API user (list below), `Adium.entitlements`, `Resources/Info.plist`

## 1. Current surface

`git grep -l AddressBook` (minus nibs/lproj/xcuserstate):

| File | Role |
|---|---|
| `Frameworks/Adium/Source/AIAddressBookController.{h,m}` (1502 lines) | the sync core: two-way name/nickname sync, IM-handle → person index, contextual menu items (Add/Edit/Show in Address Book), "me" card, change observing, implements `ABImageClient` |
| `Frameworks/Adium/Source/AIAddressBookUserIconSource.{h,m}` | contact icons from AB person images (async `ABImageClient` loads) |
| `Frameworks/Adium/Source/AIListContact.{h,m}` | `addressBookPerson` property (`ABPerson *`) |
| `Frameworks/AIUtilities/Source/OWAddressBookAdditions.{h,m}` | small AB category helpers |
| `Frameworks/AIUtilities/Source/AIImageViewWithImagePicker.m` | incidental AB reference — check and likely trivial |
| `Source/OWABSearchWindowController.m` | people-picker window (`ABPeoplePickerView`) |
| `Source/AIAddressBookInspectorPane.{h,m}`, `Source/AIInfoInspectorPane.m`, `Source/AIContactInfoContentController.{h,m}` | get-info panes showing AB data |
| `Source/AINewContactWindowController.m` | optionally files new contacts into AB |
| `Source/BGContactNotesPlugin.m` | shows the AB **notes** field in tooltips |
| `Source/ESAddressBookIntegrationAdvancedPreferences.{h,m}` | the feature's pref pane |
| `Source/AIAdium.m` | startup wiring (`startAddressBookIntegration`) |

## 2. Constraints that shape the design

1. **Access model.** `CNContactStore` requires
   `NSContactsUsageDescription` in `Resources/Info.plist` and (sandboxed) the
   `com.apple.security.personal-information.addressbook` entitlement in
   `Adium.entitlements`. First use triggers the system consent prompt;
   denial must degrade to "integration off", not a crash or a re-prompt loop.
   Authorization check: `+[CNContactStore authorizationStatusForEntityType:]`.
2. **Fetch-based, immutable objects.** No live `ABPerson` records. You fetch
   `CNContact` snapshots with explicit `keysToFetch` and you get **no
   per-record change notifications** — only the store-wide
   `CNContactStoreDidChangeNotification`. The sync core must become: build an
   in-memory index, rebuild (or refetch) on that notification.
3. **The notes field is effectively gone.** `CNContactNoteKey` requires the
   `com.apple.developer.contacts.notes` entitlement, which needs Apple
   approval and is not granted for this use case. `BGContactNotesPlugin`
   cannot be ported as-is — see §3.5.
4. **Writes** go through `CNSaveRequest` on a `CNMutableContact` copy.
5. **"Me" card:** `-[CNContactStore unifiedMeContactWithKeysToFetch:error:]`
   (macOS-only API — fine here).
6. **Picker UI:** `ABPeoplePickerView` has no Contacts twin as an embeddable
   view; ContactsUI provides `CNContactPicker` (popover-style).

## 3. Design

### 3.1 Core: restructure `AIAddressBookController` around an index

Keep the class name and its public ObjC surface (`personForListObject:` etc.)
so callers don't churn; swap the type it vends from `ABPerson *` to
`CNContact *` (this ripples into `AIListContact.addressBookPerson` — rename
the property `contactsPerson` or keep the name; keep-the-name is less churn,
implementer's call, but be consistent).

Internals:

- On start (and on `CNContactStoreDidChangeNotification`): enumerate all
  contacts once with `keysToFetch` = identifier, name components, nickname,
  `CNContactInstantMessageAddressesKey`, `CNContactEmailAddressesKey`,
  thumbnail keys — and build the same handle→person dictionaries the class
  already maintains (the existing code has this index; only its feed
  changes from AB notification userInfo diffs to full re-enumeration).
  Full re-enumeration on every change is fine at address-book scale
  (thousands of rows, sub-second) — do not build incremental diffing.
- IM-handle mapping: `CNInstantMessageAddress.service/.username` replaces the
  `kABInstantMessageProperty` multi-value walking; service-name constants
  (`CNInstantMessageServiceJabber` etc.) map from Adium service IDs the same
  way the current code maps `kABJabberInstantProperty` etc.
- Contextual menu items: "Show/Edit in Contacts" becomes opening
  `addressbook://<CNContact.identifier>` via NSWorkspace (Contacts.app URL
  scheme); "Add to Contacts" uses `CNSaveRequest`.
- Two-way sync writes (Adium nickname/icon → contact card) use
  `CNMutableContact` + `CNSaveRequest`. Wrap in the existing pref gates.

### 3.2 Icons

`AIAddressBookUserIconSource`: replace `ABImageClient` async loading with the
thumbnail data already fetched in the index (`CNContactThumbnailImageDataKey`
for list icons; fetch `CNContactImageDataKey` lazily via a keyed refetch of
one contact when full-size is needed). The class keeps its
`AIUserIconSource` conformance; only its data source changes.

### 3.3 Picker window

`OWABSearchWindowController` (nib contains an `ABPeoplePickerView`): replace
with `CNContactPicker` from ContactsUI, launched from the same button; the
window shrinks to the fields Adium adds around the picker. This is UI work —
budget it; the nib must be edited.

### 3.4 Info panes / new-contact window

Mechanical: they read properties off the person object vended by the
controller; update to `CNContact` accessors. `AINewContactWindowController`'s
"add to address book" path becomes a `CNSaveRequest`.

### 3.5 BGContactNotesPlugin (notes tooltips)

Cannot read `CNContactNoteKey` without a restricted entitlement. Decision:
**retire the plugin** — remove it and its tooltip entry, note the removal in
the changelog. Adium already has its own per-contact notes (the contact's
Adium note in the get-info pane); Apple's contact notes were duplicative.
Do not ship a build that requests the notes entitlement.

### 3.6 Migration mechanics

- Remove `AddressBook.framework` from link phases; add `Contacts.framework`
  and `ContactsUI.framework`.
- Delete `OWAddressBookAdditions` if its helpers have no CN equivalent needs
  (most are multi-value plumbing CN makes obsolete); port survivors.
- Suggested PR sequence: (1) entitlement+plist+authorization plumbing with
  integration disabled when unauthorized; (2) controller index rewrite +
  icons; (3) UI surfaces (picker, panes, new-contact); (4) notes-plugin
  removal; (5) delete AB link + dead helpers. Compiles at each step (the old
  and new stacks can't coexist in one class, so steps 2-3 land together if
  needed).

## 4. Verification

- Unit tests for the mapping layer: Adium service ID ↔ CN service constants,
  handle-index construction from fixture `CNContact`s (constructible in tests
  — `CNMutableContact` needs no store), name-preference resolution
  (first/last/nick ordering prefs). Mock at the store boundary only.
- Manual: fresh launch prompts for contacts access; deny → app fully usable,
  integration prefs show disabled state; allow → contact with a matching
  Jabber address in Contacts.app gets its name+photo in the contact list;
  edit the card in Contacts.app → Adium updates after the change
  notification; "Show in Contacts" opens the right card.

## 5. Out of scope

- Contact notes feature replacement beyond removal (§3.5).
- Any change to Adium's own metacontact/alias model.
- iCloud/CardDAV specifics — CNContactStore abstracts them.
