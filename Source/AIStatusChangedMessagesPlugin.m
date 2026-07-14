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

#import "AIStatusChangedMessagesPlugin.h"
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentStatus.h>
#import <Adium/AIListContact.h>

#define CONTACT_STATUS_UPDATE_COALESCING_KEY @"Contact Status Update"

@interface AIStatusChangedMessagesPlugin ()
- (void)statusMessage:(NSString *)message
			  forContact:(AIListContact *)contact
				withType:(NSString *)type
	phraseWithoutSubject:(NSString *)statusPhrase
		   loggedMessage:(NSAttributedString *)loggedMessage
				 inChats:(NSSet *)inChats;

- (void)contactStatusChanged:(NSNotification *)notification;
- (void)contactAwayChanged:(NSNotification *)notification;
- (void)contact_statusMessage:(NSNotification *)notification;
- (void)chatWillClose:(NSNotification *)inNotification;
@end

/*!
 * @class AIStatusChangedMessagesPlugin
 * @brief Generate <tt>AIContentStatus</tt> messages in open chats in response to contact status changes
 */
@implementation AIStatusChangedMessagesPlugin

static NSDictionary *statusTypeDict = nil;

/*!
 * @brief Install
 */
- (void)installPlugin
{
	statusTypeDict =
}

/*!
 * @brief Notification a changed status message
 *
 * @param notification <tt>NSNotification</tt> whose object is the AIListContact
 */
- (void)contact_statusMessage:(NSNotification *)notification
{
	NSSet *allChats;
	AIListContact *contact = for (chat in inChats)
	{
		// Don't do anything if the message is the same as the last message displayed for this chat
		if ([[previousStatusChangedMessages objectForKey:chat.uniqueChatID] isEqualToString:message])
			continue;

		AIContentStatus *content;

		// Create our content object
		content = [AIContentStatus statusInChat:chat
									 withSource:contact
									destination:chat.account
										   date:[NSDate date]
										message:attributedMessage
									   withType:type];

		if (statusPhrase) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:statusPhrase forKey:@"Status Phrase"];
			[content setUserInfo:userInfo];
		}

		if (loggedMessage) {
			[content setLoggedMessage:loggedMessage];
		}

		[content setCoalescingKey:CONTACT_STATUS_UPDATE_COALESCING_KEY];

		// Add the object
		[adium.contentController receiveContentObject:content];

		// Keep track of this message for this chat so we don't display it again sequentially
		[previousStatusChangedMessages setObject:message forKey:chat.uniqueChatID];
	}
}

- (void)chatWillClose:(NSNotification *)inNotification
{
	AIChat *chat = [inNotification object];
	[previousStatusChangedMessages removeObjectForKey:chat.uniqueChatID];
}

@end
