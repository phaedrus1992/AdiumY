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

#import "AMPurpleJabberMessageStyling.h"
#import "ESPurpleJabberAccount.h"
#import <libpurple/jabber.h>

/// The XEP-0393 Message Styling namespace.
#define NS_MESSAGE_STYLING @"urn:xmpp:styling:0"

@interface AMPurpleJabberMessageStyling ()

@end

/// C callback for the jabber-receiving-xmlnode signal.
///
/// Checks incoming message stanzas for the presence of an <unstyled/> element
/// in the urn:xmpp:styling:0 namespace.
///
/// @param gc The PurpleConnection
/// @param packet Pointer to the xmlnode (unused, read-only)
/// @param data The AMPurpleJabberMessageStyling instance (as void*)
static void AMPurpleJabberMessageStyling_received_xmlnode_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {

		@try {
			AMPurpleJabberMessageStyling *self = (__bridge AMPurpleJabberMessageStyling *)data;
			xmlnode *node = *packet;

			if (node == NULL || gc == NULL || self == nil) {
				return;
			}

			// Only process message stanzas
			if (strcmp(node->name, "message") != 0) {
				return;
			}

			// Look for <unstyled xmlns="urn:xmpp:styling:0"/> child
			xmlnode *unstyled = xmlnode_get_child_with_namespace(node, "unstyled", [NS_MESSAGE_STYLING UTF8String]);
			if (unstyled != NULL) {
				self->_lastMessageHadUnstyled = YES;
				AILog(@"AMPurpleJabberMessageStyling: Detected <unstyled/> in message");
			}

		} @catch (NSException *exception) {
			AILog(@"AMPurpleJabberMessageStyling: exception handling stanza: %@", exception);
		}
	}
}

#pragma mark -

@implementation AMPurpleJabberMessageStyling

+ (void)initialize
{
	if (self == [AMPurpleJabberMessageStyling class]) {
		jabber_add_feature([NS_MESSAGE_STYLING UTF8String], NULL);
	}
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;
		_lastMessageHadUnstyled = NO;

		// Connect to jabber-receiving-xmlnode to detect <unstyled/> elements
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber != NULL) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", self,
								  PURPLE_CALLBACK(AMPurpleJabberMessageStyling_received_xmlnode_cb),
								  (__bridge void *)self);
		}

		AILog(@"AMPurpleJabberMessageStyling: initialized for %@", [account UID]);
	}

	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);

	[super dealloc];
}

#pragma mark - Public

- (BOOL)lastMessageHadUnstyled
{
	BOOL hadIt = _lastMessageHadUnstyled;
	_lastMessageHadUnstyled = NO; // One-shot: clear after reading
	return hadIt;
}

@end
