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

#import "AMPurpleJabberCorrection.h"
#import "ESPurpleJabberAccount.h"
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AISharedAdium.h>
#import <libpurple/jabber.h>

#define NS_MESSAGE_CORRECT @"urn:xmpp:message-correct:0"

NSString *const AICorrectionNotificationName = @"AIMessageCorrection";
NSString *const AICorrectionChatKey = @"AICorrectionChat";
NSString *const AICorrectionSenderKey = @"AICorrectionSender";
NSString *const AICorrectionDOMIdKey = @"AICorrectionDOMId";
NSString *const AICorrectionHTMLKey = @"AICorrectionHTML";
NSString *const AICorrectionStanzaTrackedNotification = @"AIMessageStanzaTracked";
NSString *const AICorrectionStanzaIDKey = @"AICorrectionStanzaID";

@interface AMPurpleJabberCorrection ()

/// Build the DOM id for a message element: `msg-in-<bareJID>-<stanzaId>`
+ (NSString *)domIdForBareJID:(NSString *)bareJID stanzaId:(NSString *)stanzaId;

/// Extract the bare JID (without resource) from a full JID string.
+ (NSString *)bareJIDFromString:(const char *)jidCString;

@end

static void AMPurpleJabberCorrection_received_data_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {

		@try {
			AMPurpleJabberCorrection *self = (__bridge AMPurpleJabberCorrection *)data;
			xmlnode *node = *packet;

			if (!node || !gc || !self) {
				return;
			}

			// Only process message stanzas
			if (strcmp(node->name, "message") != 0) {
				return;
			}

			// Skip group chat messages (corrections in MUC are out of scope)
			const char *msgType = xmlnode_get_attrib(node, "type");
			if (msgType != NULL && strcmp(msgType, "groupchat") == 0) {
				return;
			}

			// Must have a <body> element to be a displayable message
			xmlnode *body = xmlnode_get_child(node, "body");
			if (!body || !body->child || !body->child->data) {
				return;
			}

			const char *from = xmlnode_get_attrib(node, "from");
			if (!from) {
				return;
			}

			NSString *bareJID = [AMPurpleJabberCorrection bareJIDFromString:from];

			// Check for a <replace> element (XEP-0308 correction)
			xmlnode *replace = xmlnode_get_child_with_namespace(node, "replace", [NS_MESSAGE_CORRECT UTF8String]);
			if (replace) {
				const char *replaceID = xmlnode_get_attrib(replace, "id");
				if (!replaceID) {
					return;
				}

				NSString *replaceStanzaID = @(replaceID);
				NSString *trackedID = [self->_trackedStanzaIDs objectForKey:bareJID];

				// Anti-spoofing: only accept correction if the replaced ID matches our tracked last stanza
				if (trackedID != nil && [trackedID isEqualToString:replaceStanzaID]) {
					const char *bodyText = (const char *)body->child->data;
					NSString *correctedBody = bodyText ? @(bodyText) : @"";
					NSString *domId = [AMPurpleJabberCorrection domIdForBareJID:bareJID stanzaId:replaceStanzaID];

					// Find the chat for this message
					PurpleAccount *account = purple_connection_get_account(gc);
					PurpleConversation *conv =
						purple_find_conversation_with_account(PURPLE_CONV_TYPE_IM, [bareJID UTF8String], account);
					AIChat *chat = nil;
					if (conv) {
						chat = [adium.chatController existingChatWithName:bareJID onAccount:self->_account];
					}

					// Update tracked ID to the correction's own stanza ID for chained corrections
					const char *stanzaID = xmlnode_get_attrib(node, "id");
					if (stanzaID) {
						[self->_trackedStanzaIDs setObject:@(stanzaID) forKey:bareJID];
					}

					NSDictionary *userInfo = @{
						AICorrectionChatKey : (chat ?: [NSNull null]),
						AICorrectionSenderKey : bareJID,
						AICorrectionDOMIdKey : domId,
						AICorrectionHTMLKey : correctedBody,
					};
					[[NSNotificationCenter defaultCenter] postNotificationName:AICorrectionNotificationName
																		object:chat
																	  userInfo:userInfo];

					// Consume the packet so Purple does not display the original body
					xmlnode_free(*packet);
					*packet = NULL;
				}
				// If trackedID doesn't match, fall through — deliver as normal message (anti-spoofing)

				return;
			}

			// Normal message with body: track the stanza ID
			const char *stanzaID = xmlnode_get_attrib(node, "id");
			if (stanzaID) {
				NSString *stanzaIDStr = @(stanzaID);
				[self->_trackedStanzaIDs setObject:stanzaIDStr forKey:bareJID];

				// Post notification so the view controller can set DOM ids on displayed messages
				NSString *trackedDomId = [AMPurpleJabberCorrection domIdForBareJID:bareJID stanzaId:stanzaIDStr];
				NSDictionary *trackedInfo = @{
					AICorrectionSenderKey : bareJID,
					AICorrectionStanzaIDKey : stanzaIDStr,
					AICorrectionDOMIdKey : trackedDomId,
				};
				[[NSNotificationCenter defaultCenter] postNotificationName:AICorrectionStanzaTrackedNotification
																	object:nil
																  userInfo:trackedInfo];
			}

		} @catch (NSException *exception) {
			AILog(@"AMPurpleJabberCorrection: exception handling stanza: %@", exception);
		}
	}
}

#pragma mark -

@implementation AMPurpleJabberCorrection

+ (void)initialize
{
	if (self == [AMPurpleJabberCorrection class]) {
		jabber_add_feature([NS_MESSAGE_CORRECT UTF8String], NULL);
	}
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;
		_trackedStanzaIDs = [[NSMutableDictionary alloc] init];

		// Connect to jabber-receiving-xmlnode to intercept message stanzas
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", (__bridge void *)self,
								  PURPLE_CALLBACK(AMPurpleJabberCorrection_received_data_cb), (__bridge void *)self);
		}

		AILog(@"AMPurpleJabberCorrection: initialized for %@", account.UID);
	}

	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);
}

#pragma mark - Helpers

+ (NSString *)domIdForBareJID:(NSString *)bareJID stanzaId:(NSString *)stanzaId
{
	return [NSString stringWithFormat:@"msg-in-%@-%@", bareJID, stanzaId];
}

+ (NSString *)bareJIDFromString:(const char *)jidCString
{
	if (!jidCString)
		return @"";

	NSString *jid = @(jidCString);
	NSRange slashRange = [jid rangeOfString:@"/"];
	if (slashRange.location != NSNotFound) {
		return [jid substringToIndex:slashRange.location];
	}

	return jid;
}

@end
