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

#import "AIAutoReplyPlugin.h"
#import "AIStatusController.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIStatus.h>

@interface AIAutoReplyPlugin ()
- (void)didReceiveContent:(NSNotification *)notification;
- (void)didSendContent:(NSNotification *)notification;
- (void)chatWillClose:(NSNotification *)notification;
@end

/*!
 * @class AIAutoReplyPlugin
 * @brief Provides AutoReply functionality for the state system
 *
 * This class implements the state system behavior for auto-reply.  If auto-reply status is active on an account,
 * initial messages recieved on that account will be replied to automatically.  Subsequent messages will not receive
 * a reply unless the chat window is closed.
 *
 * This is the expected behavior on certain protocols such as AIM, and considered a convenience on other protocols.
 */
@implementation AIAutoReplyPlugin

/*!
 * @brief Initialize the auto-reply system
 *
 * Initialize the auto-reply system to monitor account status.  When an account auto-reply flag is set we begin to
 * monitor chat messaging and auto-reply as necessary.
 */
- (void)installPlugin
{
	// Init
	receivedAutoReply = receivedAutoReply = [mutableAutoReply
		replaceCharactersInRange:NSMakeRange(0, 0)
					  withString:AILocalizedString(@"(Autoreply) ",
												   "Prefix to place before autoreplies on services which do "
												   "not natively support them")];
	autoReply = mutableAutoReply;
}

responseContent = [AIContentMessage messageInChat:chat
									   withSource:source
									  destination:destination
											 date:nil
										  message:autoReply
										autoreply:supportsAutoreply];

[adium.contentController sendContentObject:responseContent];
}
}

/*!
 * @brief Respond to our user sending messages
 *
 * For convenience, when our user messages a contact while away we exclude that contact from receiving our auto-away
 * on future messages.
 */
- (void)didSendContent:(NSNotification *)notification
{
	AIContentObject *contentObject = [[notification userInfo] objectForKey:@"AIContentObject"];
	AIChat *chat = contentObject.chat;

	if ([[contentObject type] isEqualToString:CONTENT_MESSAGE_TYPE]) {
		[receivedAutoReply addObject:chat.uniqueChatID];
	}
}

- (void)removeChatIDFromReceivedAutoReply:(id)uniqueChatID
{
	[receivedAutoReply removeObject:uniqueChatID];
}

/*!
 * @brief Respond to a chat closing
 *
 * Once a chat is closed we forget about whether it has received an auto-response.  If the chat is re-opened, it will
 * receive our auto-response again.  This behavior is not necessarily desired, but is a side effect of basing our
 * already-received list on chats and not contacts.  However, many users have come to expect this behavior and it's
 * presence is neither strongly negative or positive.
 */
- (void)chatWillClose:(NSNotification *)notification
{
	/* Don't remove the chat until 30 seconds from now to prevent the classic situation in which you close the window,
	 * the contact messages you one last message, and a needless autoreply is sent
	 */
	[NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:@selector(removeChatIDFromReceivedAutoReply:)
											   object:[[notification object] uniqueChatID]];
	[self performSelector:@selector(removeChatIDFromReceivedAutoReply:)
			   withObject:[[notification object] uniqueChatID]
			   afterDelay:30.0];
}

@end
