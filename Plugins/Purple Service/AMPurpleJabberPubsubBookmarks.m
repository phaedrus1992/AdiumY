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

#import "AMPurpleJabberPubsubBookmarks.h"
#import "ESPurpleJabberAccount.h"
#import <libpurple/jabber.h>

#define NS_PUBSUB_BOOKMARKS @"urn:xmpp:bookmarks:1"
#define NS_PUBSUB @"http://jabber.org/protocol/pubsub"
#define NS_PUBSUB_EVENT @"http://jabber.org/protocol/pubsub#event"

#define AMPurpleJabberPubsubBookmarksIQRetrieveId @"pubsub-bm-retrieve-1"
#define AMPurpleJabberPubsubBookmarksIQPublishId @"pubsub-bm-publish-1"

@interface AMPurpleJabberPubsubBookmarks ()

/// Build the IQ-get stanza for retrieving bookmarks via PubSub (PEP).
- (NSString *)_xmlForRetrieve;

/// Build the IQ-set stanza for publishing bookmarks via PubSub (PEP).
///
/// @param bookmarksXML The inner \c <conference> elements XML
/// @return An XML string appropriate for jabber_prpl_send_raw
- (NSString *)_xmlForPublishWithBookmarksXML:(NSString *)bookmarksXML;

@end

static void AMPurpleJabberPubsubBookmarks_received_xmlnode_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {

		@try {
			AMPurpleJabberPubsubBookmarks *self = (__bridge AMPurpleJabberPubsubBookmarks *)data;
			xmlnode *node = *packet;

			if (!node || !gc || !self) {
				return;
			}

			xmlnode *itemsNode = NULL;

			// Handle IQ/result with PubSub items (retrieve response)
			if (strcmp(node->name, "iq") == 0) {
				const char *iqType = xmlnode_get_attrib(node, "type");
				if (!iqType || strcmp(iqType, "result") != 0) {
					return;
				}

				xmlnode *pubsub = xmlnode_get_child_with_namespace(node, "pubsub", [NS_PUBSUB UTF8String]);
				if (!pubsub) {
					return;
				}

				itemsNode = xmlnode_get_child_with_namespace(pubsub, "items", [NS_PUBSUB UTF8String]);
			}
			// Handle Message with PubSub event (PEP notification)
			else if (strcmp(node->name, "message") == 0) {
				xmlnode *event = xmlnode_get_child_with_namespace(node, "event", [NS_PUBSUB_EVENT UTF8String]);
				if (!event) {
					return;
				}

				itemsNode = xmlnode_get_child_with_namespace(event, "items", [NS_PUBSUB_EVENT UTF8String]);
			} else {
				return;
			}

			if (!itemsNode) {
				return;
			}

			// Verify the items node is for our bookmarks namespace
			const char *itemsNodeAttrib = xmlnode_get_attrib(itemsNode, "node");
			if (!itemsNodeAttrib || strcmp(itemsNodeAttrib, [NS_PUBSUB_BOOKMARKS UTF8String]) != 0) {
				return;
			}

			// Parse conference elements from items
			NSMutableArray *conferences = [NSMutableArray array];

			for (xmlnode *item = itemsNode->child; item; item = item->next) {
				if (item->type != XMLNODE_TYPE_TAG || strcmp(item->name, "item") != 0) {
					continue;
				}

				for (xmlnode *child = item->child; child; child = child->next) {
					if (child->type != XMLNODE_TYPE_TAG || strcmp(child->name, "conference") != 0) {
						continue;
					}

					const char *jid = xmlnode_get_attrib(child, "jid");
					const char *name = xmlnode_get_attrib(child, "name");
					const char *autojoin = xmlnode_get_attrib(child, "autojoin");

					if (!jid || !name) {
						continue;
					}

					// Extract optional <nick> child
					NSString *nick = nil;
					xmlnode *nickNode = xmlnode_get_child(child, "nick");
					if (nickNode && nickNode->child && nickNode->child->data) {
						nick = @((const char *)nickNode->child->data);
					}

					NSMutableDictionary *conference = [NSMutableDictionary dictionary];
					[conference setObject:@(jid) forKey:@"jid"];
					[conference setObject:@(name) forKey:@"name"];
					if (autojoin) {
						[conference setObject:@(autojoin) forKey:@"autojoin"];
					}
					if (nick) {
						[conference setObject:nick forKey:@"nick"];
					}

					[conferences addObject:conference];
				}
			}

			NSDictionary *userInfo = @{
				@"bookmarks" : conferences,
			};
			[[NSNotificationCenter defaultCenter] postNotificationName:@"AIPubsubBookmarksReceived"
																object:self
															  userInfo:userInfo];

			AILog(@"AMPurpleJabberPubsubBookmarks: Received %lu bookmark(s)", (unsigned long)[conferences count]);

		} @catch (NSException *exception) {
			AILog(@"AMPurpleJabberPubsubBookmarks: exception handling stanza: %@", exception);
		}
	}
}

#pragma mark -

@implementation AMPurpleJabberPubsubBookmarks

+ (void)initialize
{
	if (self == [AMPurpleJabberPubsubBookmarks class]) {
		jabber_add_feature([NS_PUBSUB_BOOKMARKS UTF8String], NULL);
	}
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;

		// Connect to jabber-receiving-xmlnode to intercept PubSub results for bookmarks
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", self,
								  PURPLE_CALLBACK(AMPurpleJabberPubsubBookmarks_received_xmlnode_cb),
								  (__bridge void *)self);
		}

		AILog(@"AMPurpleJabberPubsubBookmarks: initialized for %@", [account UID]);
	}

	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);

	[super dealloc];
}

#pragma mark - Public

- (void)retrieveBookmarks
{
	NSString *xml = [self _xmlForRetrieve];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc != nil) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		AILog(@"AMPurpleJabberPubsubBookmarks: Sent bookmarks retrieve query");
	}
}

- (void)publishBookmarksWithXML:(NSString *)bookmarksXML
{
	NSString *xml = [self _xmlForPublishWithBookmarksXML:bookmarksXML];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc != nil) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		AILog(@"AMPurpleJabberPubsubBookmarks: Sent bookmarks publish query");
	}
}

#pragma mark - Private

- (NSString *)_xmlForRetrieve
{
	return [NSString stringWithFormat:@"<iq type='get' id='%@'>"
									  @"<pubsub xmlns='%@'>"
									  @"<items node='%@'/>"
									  @"</pubsub>"
									  @"</iq>",
									  AMPurpleJabberPubsubBookmarksIQRetrieveId, NS_PUBSUB, NS_PUBSUB_BOOKMARKS];
}

- (NSString *)_xmlForPublishWithBookmarksXML:(NSString *)bookmarksXML
{
	return [NSString stringWithFormat:@"<iq type='set' id='%@'>"
									  @"<pubsub xmlns='%@'>"
									  @"<publish node='%@'>"
									  @"<item id='current'>"
									  @"%@"
									  @"</item>"
									  @"</publish>"
									  @"</pubsub>"
									  @"</iq>",
									  AMPurpleJabberPubsubBookmarksIQPublishId, NS_PUBSUB, NS_PUBSUB_BOOKMARKS,
									  bookmarksXML];
}

@end
