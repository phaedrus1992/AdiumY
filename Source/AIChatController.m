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

#import "AIChatController.h"

#import "AdiumChatEvents.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIService.h>
#import <Adium/AIStatusControllerProtocol.h>

#import "DCMessageContextDisplayPlugin.h"

#define SHOW_JOIN_LEAVE_TITLE AILocalizedString(@"Show Join/Leave Messages", nil)

@interface AIChatController ()
- (NSSet *)_informObserversOfChatStatusChange:(AIChat *)inChat withKeys:(NSSet *)modifiedKeys silent:(BOOL)silent;
- (void)chatAttributesChanged:(AIChat *)inChat modifiedKeys:(NSSet *)inModifiedKeys;

- (void)toggleIgnoreOfContact:(id)sender;
- (void)toggleShowJoinLeave:(id)sender;
- (void)didExchangeContent:(NSNotification *)notification;

- (void)adiumWillTerminate:(NSNotification *)inNotification;
@end

/*!
 * @class AIChatController
 * @brief Core controller for chats
 *
 * This is the only class which should vend AIChat objects (via openChat... or chatWith:...).
 * AIChat objects should never be created directly.
 */
@implementation AIChatController

/*!
 * @brief Initialize the controller
 */
- (id)init
{
	if ((self = 
			mostRecentChat = chat;
}
}
}

#pragma mark Menu Items
/*!
 * @brief Toggle ignoring of a contact
 *
 * Must be called from the contextual menu for the contact within a chat
 */
- (void)toggleIgnoreOfContact:(id)sender
{
	AIListObject *listObject = adium.menuController.currentContextMenuObject;
	AIChat *chat = [adium.menuController currentContextMenuChat];

	if ([listObject isKindOfClass:[AIListContact class]]) {
		BOOL isIgnored = [chat isListContactIgnored:(AIListContact *)listObject];
		[chat setListContact:(AIListContact *)listObject isIgnored:!isIgnored];
	}
}

/*!
 * @brief Toggle displaying of show/part messages for a chat
 *
 * Effects the currently active chat.
 */
- (void)toggleShowJoinLeave:(id)sender
{
	AIChat *chat = nil;

	if (sender == menuItem_joinLeave) {
		chat = adium.interfaceController.activeChat;
	} else {
		chat = adium.menuController.currentContextMenuChat;
	}

	chat.showJoinLeave = !chat.showJoinLeave;

	[[adium preferenceController] setPreference:[NSNumber numberWithBool:!chat.showJoinLeave]
										 forKey:[NSString stringWithFormat:@"HideJoinLeave-%@", chat.name]
										  group:PREF_GROUP_STATUS_PREFERENCES];
}

/*!
 * @brief Menu item validation
 *
 * When asked to validate our ignore menu item, set its title to ignore/un-ignore as appropriate for the contact
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem == menuItem_ignore) {
		AIListObject *listObject = adium.menuController.currentContextMenuObject;
		AIChat *chat = [adium.menuController currentContextMenuChat];

		if ([listObject isKindOfClass:[AIListContact class]]) {
			if ([chat isListContactIgnored:(AIListContact *)listObject]) {
				[menuItem setTitle:AILocalizedString(
									   @"Un-ignore",
									   "Un-ignore means begin receiving messages from this contact again in a chat")];

			} else {
				[menuItem
					setTitle:AILocalizedString(@"Ignore",
											   "Ignore means no longer receive messages from this contact in a chat")];
			}
		} else {
			[menuItem setTitle:AILocalizedString(
								   @"Ignore", "Ignore means no longer receive messages from this contact in a chat")];
			return NO;
		}
	} else if ([menuItem.title isEqualToString:SHOW_JOIN_LEAVE_TITLE]) {
		// We're using multiple menu items for the same goal, and WKMV makes a copy of the contextual ones.
		// Validate based on the title.
		AIChat *chat = nil;
		if (menuItem == menuItem_joinLeave) {
			chat = adium.interfaceController.activeChat;
		} else {
			chat = adium.menuController.currentContextMenuChat;
		}

		if (chat.isGroupChat) {
			[menuItem setState:chat.showJoinLeave];
			return YES;
		}

		return NO;
	}

	return YES;
}

#pragma mark Chat contact addition and removal

/*!
 * @brief A chat added a listContact to its participatants list
 *
 * @param chat The chat
 * @param inContact The contact
 * @param notify If YES, trigger the contact joined event if this is a group chat.  Ignored if this is not a group chat.
 */
- (void)chat:(AIChat *)chat addedListContacts:(NSArray *)inObjects notify:(BOOL)notify
{
	if (notify && chat.isGroupChat) {
		/* Prevent triggering of the event when we are informed that the chat's own account entered the chat
		 * If the UID of a contact in a chat differs from a normal UID, such as is the case with Jabber where a chat
		 * contact has the form "roomname@conferenceserver/handle" this will fail, but it's better than nothing.
		 */
		for (AIListContact *inContact in inObjects) {
			if (![inContact.account.UID isEqualToString:inContact.UID]) {
				[adiumChatEvents chat:chat addedListContact:inContact];
			}
		}
	}

	// Always notify Adium that the list changed so it can be updated, caches can be modified, etc.
	[[NSNotificationCenter defaultCenter] postNotificationName:Chat_ParticipatingListObjectsChanged object:chat];
}

/*!
 * @brief A chat removed a listContact from its participants list
 *
 * @param chat The chat
 * @param inContact The contact
 */
- (void)chat:(AIChat *)chat removedListContact:(AIListContact *)inContact
{
	if (chat.isGroupChat) {
		[adiumChatEvents chat:chat removedListContact:inContact];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:Chat_ParticipatingListObjectsChanged object:chat];
}

- (NSString *)defaultInvitationMessageForRoom:(NSString *)room account:(AIAccount *)inAccount
{
	return [NSString stringWithFormat:AILocalizedString(@"%@ invites you to join the chat \"%@\"", nil),
									  inAccount.formattedUID, room];
}

@end

/*
 * These strings were used previously; we may want them again. Keeping the translations around for now.
  AILocalizedString("%@ joined the chat", nil);
  AILocalizedString("%@ left the chat", nil);
 */
