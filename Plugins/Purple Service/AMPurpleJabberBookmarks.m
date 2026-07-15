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

#import "AMPurpleJabberBookmarks.h"
#import "ESPurpleJabberAccount.h"
#import <libpurple/jabber.h>

#define NS_BOOKMARKS @"storage:bookmarks"
#define NS_PRIVATE_XML @"jabber:iq:private"

#define AMPurpleJabberBookmarksIQRetrieveId @"bookmarks-retrieve-1"

@interface AMPurpleJabberBookmarks ()

/// Build the IQ-get stanza for retrieving bookmarks via Private XML Storage.
- (NSString *)_xmlForRetrieve;

/// Build the IQ-set stanza for storing bookmarks via Private XML Storage.
///
/// @param bookmarksXML The inner \c <storage> element XML
/// @return An XML string appropriate for jabber_prpl_send_raw
- (NSString *)_xmlForStoreWithBookmarksXML:(NSString *)bookmarksXML;

@end

static void AMPurpleJabberBookmarks_received_xmlnode_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {

		@try {
			AMPurpleJabberBookmarks *self = (__bridge AMPurpleJabberBookmarks *)data;
			xmlnode *node = *packet;

			if (!node || !gc || !self) {
				return;
			}

			// Only process IQ stanzas
			if (strcmp(node->name, "iq") != 0) {
				return;
			}

			const char *iqType = xmlnode_get_attrib(node, "type");
			if (!iqType || strcmp(iqType, "result") != 0) {
				return;
			}

			// Look for <query xmlns='jabber:iq:private'>
			xmlnode *query = xmlnode_get_child_with_namespace(node, "query", [NS_PRIVATE_XML UTF8String]);
			if (!query) {
				return;
			}

			// Look for <storage xmlns='storage:bookmarks'> within the query
			xmlnode *storage = xmlnode_get_child_with_namespace(query, "storage", [NS_BOOKMARKS UTF8String]);
			if (!storage) {
				return;
			}

			// Successfully received bookmarks storage data
			// Post a notification so interested parties can process the bookmarks
			NSMutableArray *conferences = [NSMutableArray array];

			for (xmlnode *child = storage->child; child; child = child->next) {
				if (child->type == XMLNODE_TYPE_TAG && strcmp(child->name, "conference") == 0) {
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
			[[NSNotificationCenter defaultCenter] postNotificationName:@"AIBookmarksReceived"
																object:self
															  userInfo:userInfo];

			AILog(@"AMPurpleJabberBookmarks: Received %lu bookmark(s)", (unsigned long)[conferences count]);

		} @catch (NSException *exception) {
			AILog(@"AMPurpleJabberBookmarks: exception handling stanza: %@", exception);
		}
	}
}

#pragma mark -

@implementation AMPurpleJabberBookmarks

+ (void)initialize
{
	if (self == [AMPurpleJabberBookmarks class]) {
		jabber_add_feature([NS_BOOKMARKS UTF8String], NULL);
	}
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;

		// Connect to jabber-receiving-xmlnode to intercept IQ results for bookmarks
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", (__bridge void *)self,
								  PURPLE_CALLBACK(AMPurpleJabberBookmarks_received_xmlnode_cb), (__bridge void *)self);
		}

		AILog(@"AMPurpleJabberBookmarks: initialized for %@", account.UID);
	}

	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);
}

#pragma mark - Public

- (void)retrieveBookmarks
{
	NSString *xml = [self _xmlForRetrieve];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		AILog(@"AMPurpleJabberBookmarks: Sent bookmarks retrieve query");
	}
}

- (void)storeBookmarksWithXML:(NSString *)storageXML
{
	NSString *xml = [self _xmlForStoreWithBookmarksXML:storageXML];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		AILog(@"AMPurpleJabberBookmarks: Sent bookmarks store query");
	}
}

#pragma mark - Private

- (NSString *)_xmlForRetrieve
{
	return [NSString stringWithFormat:@"<iq type='get' id='%@'>"
									  @"<query xmlns='%@'>"
									  @"<storage xmlns='%@'/>"
									  @"</query>"
									  @"</iq>",
									  AMPurpleJabberBookmarksIQRetrieveId, NS_PRIVATE_XML, NS_BOOKMARKS];
}

- (NSString *)_xmlForStoreWithBookmarksXML:(NSString *)bookmarksXML
{
	return [NSString stringWithFormat:@"<iq type='set' id='bookmarks-store-1'>"
									  @"<query xmlns='%@'>"
									  @"%@"
									  @"</query>"
									  @"</iq>",
									  NS_PRIVATE_XML, bookmarksXML];
}

@end
