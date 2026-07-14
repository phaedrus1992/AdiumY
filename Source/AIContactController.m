/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIContactController.h"

#import "AISCLViewPlugin.h"
#import <Adium/AIContactHidingController.h>

#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AILoginControllerProtocol.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIToolbarControllerProtocol.h>

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContactList.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AISortController.h>
#import <Adium/AIUserIcons.h>

#define KEY_FLAT_GROUPS @"FlatGroups"             // Group storage
#define KEY_FLAT_CONTACTS @"FlatContacts"         // Contact storage
#define KEY_FLAT_METACONTACTS @"FlatMetaContacts" // Metacontact objectID storage
#define KEY_BOOKMARKS @"Bookmarks"

#define TOP_METACONTACT_ID @"TopMetaContactID"
#define KEY_IS_METACONTACT @"isMetaContact"
#define KEY_OBJECTID @"objectID"
#define KEY_METACONTACT_OWNERSHIP @"MetaContact Ownership"
#define CONTACT_DEFAULT_PREFS @"ContactPrefs"

#define SHOW_GROUPS_MENU_TITLE AILocalizedString(@"Show Groups", nil)

#define SHOW_GROUPS_IDENTIFER @"ShowGroups"

#define SERVICE_ID_KEY @"ServiceID"
#define UID_KEY @"UID"

// #define CONTACT_MOVEMENT_DEBUG

@interface AIListObject ()
@property(readwrite, nonatomic) CGFloat orderIndex;
@end

@interface AIMetaContact ()
- (BOOL)addObject:(AIListObject *)inObject;
- (BOOL)removeObject:(AIListObject *)inObject;
- (AIListContact *)preferredContactForContentType:(NSString *)inType;
@end

@interface AIListGroup ()
- (void)removeObject:(AIListObject *)inObject;
- (BOOL)addObject:(AIListObject *)inObject;
@end

@interface AIContactList ()
- (void)removeObject:(AIListObject *)inObject;
- (BOOL)addObject:(AIListObject *)inObject;
@end

@interface AIListBookmark ()
// Freshly minted bookmarks don't know where to restore to, since they have no serverside counterpart. This tells them.
- (void)setInitialGroup:(AIListGroup *)inGroup;
@end

@interface AIContactController ()
@property(readwrite, nonatomic) BOOL useOfflineGroup;
- (void)saveContactList;
- (void)_loadBookmarks;
- (void)_didChangeContainer:(id<AIContainingObject>)inContainingObject object:(AIListObject *)object;
- (void)prepareShowHideGroups;
- (void)_performChangeOfUseContactListGroups;
- (void)didSendContent:(NSNotification *)notification;
- (IBAction)toggleShowGroups:(id)sender;

// MetaContacts
- (BOOL)_restoreContactsToMetaContact:(AIMetaContact *)metaContact;
- (void)_restoreContactsToMetaContact:(AIMetaContact *)metaContact
		   fromContainedContactsArray:(NSArray *)containedContactsArray;
- (void)addContact:(AIListContact *)inContact toMetaContact:(AIMetaContact *)metaContact;
- (BOOL)_performAddContact:(AIListContact *)inContact toMetaContact:(AIMetaContact *)metaContact;
- (void)removeContact:(AIListContact *)inContact fromMetaContact:(AIMetaContact *)metaContact;
- (void)_loadMetaContactsFromArray:(NSArray *)array;
- (void)_saveMetaContacts:(NSDictionary *)allMetaContactsDict;
- (void)_storeListObject:(AIListObject *)listObject inMetaContact:(AIMetaContact *)metaContact;
@end

@implementation AIContactController

- (id)init
{
	if ((self = 
	return list;
}

/*!
 * @brief Removes detached contact list
 */
- (void)removeDetachedContactList:(AIContactList *)detachedList
{
	[contactLists removeObject:detachedList];
}

@end

@implementation AIContactController (ContactControllerHelperAccess)
- (NSEnumerator *)contactEnumerator
{
	return [contactDict objectEnumerator];
}
- (NSEnumerator *)groupEnumerator
{
	return [groupDict objectEnumerator];
}
- (NSEnumerator *)bookmarkEnumerator
{
	return [bookmarkDict objectEnumerator];
}
@end
