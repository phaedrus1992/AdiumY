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

#import "AIContentController.h"

#import "AdiumContentFiltering.h"
#import "AdiumFormatting.h"
#import "AdiumMessageEvents.h"
#import "AdiumTyping.h"

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFontAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITextAttachmentAdditions.h>
#import <AIUtilities/AITextAttributes.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactAlertsControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentEvent.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIContentNotification.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIFileTransferControllerProtocol.h>
#import <Adium/AIHTMLDecoder.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AITextAttachmentExtension.h>
#import <Adium/ESFileTransfer.h>

@interface AIContentController ()
- (void)finishReceiveContentObject:(AIContentObject *)inObject;
- (void)finishSendContentObject:(AIContentObject *)inObject;
- (void)finishDisplayContentObject:(AIContentObject *)inObject;

- (void)displayContentObject:(AIContentObject *)inObject immediately:(BOOL)immediately;

- (BOOL)processAndSendContentObject:(AIContentObject *)inContentObject;

- (void)didFilterAttributedString:(NSAttributedString *)filteredMessage receivingContext:(AIContentObject *)inObject;
- (void)didFilterAttributedString:(NSAttributedString *)filteredString
			contentSendingContext:(AIContentObject *)inObject;
- (void)didFilterAttributedString:(NSAttributedString *)filteredString
		  autoreplySendingContext:(AIContentObject *)inObject;
- (void)didFilterAttributedString:(NSAttributedString *)filteredString
	  contentFilterDisplayContext:(AIContentObject *)inObject;
- (void)didFilterAttributedString:(NSAttributedString *)filteredString displayContext:(AIContentObject *)inObject;
@end

/*!
 * @class AIContentController
 * @brief Controller to manage incoming and outgoing content and chats.
 *
 * This controller handles default formatting and text entry filters, which can respond as text is entered in a message
 * window.  It the center for content filtering, including registering/unregistering of content filters.
 * It handles sending and receiving of content objects.  It manages chat observers, which are objects notified as
 * properties are set and removed on AIChat objects.  It manages chats themselves, tracking open ones, closing
 * them when needed, etc.  Finally, it provides Events related to sending and receiving content, such as Message
 * Received.
 */
@implementation AIContentController

/*!
 * @brief Initialize the controller
 */
- (id)init
{
	if ((self =
}

return
}

@end
