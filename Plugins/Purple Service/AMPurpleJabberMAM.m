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

#import "AMPurpleJabberMAM.h"
#import "ESPurpleJabberAccount.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentContext.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AISharedAdium.h>
#import <libpurple/jabber.h>

#define NS_MAM @"urn:xmpp:mam:2"
#define NS_FORWARD @"urn:xmpp:forward:0"
#define NS_RSM @"http://jabber.org/protocol/rsm"
#define NS_DELAY @"urn:xmpp:delay"

#define KEY_MAM_ENABLED @"Jabber:Enable MAM"
#define KEY_LAST_ARCHIVE_ID @"Jabber:lastArchiveID"

#define MAM_PAGE_SIZE 50

@interface AMPurpleJabberMAM ()
- (void)_sendQueryWithAfter:(NSString *)after;
- (void)_sendQueryWithBefore;
- (void)_handleResult:(xmlnode *)result;
- (void)_handleFin:(xmlnode *)fin;
- (void)_saveLastArchiveID:(NSString *)archiveID;
- (NSString *)_loadLastArchiveID;
- (void)_displayMessage:(NSString *)body from:(NSString *)fromJID to:(NSString *)toJID date:(NSDate *)date;
- (NSDate *)_parseStamp:(const char *)stamp;
@end

static void AMPurpleJabberMAM_received_data_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {
		@try {
			AMPurpleJabberMAM *self = (__bridge AMPurpleJabberMAM *)data;
			xmlnode *node = *packet;

			if (!node || !gc || !self) {
				return;
			}

			// Handle IQ error responses for MAM queries
			if (strcmp(node->name, "iq") == 0) {
				const char *iq_type = xmlnode_get_attrib(node, "type");
				if (iq_type != NULL && strcmp(iq_type, "error") == 0) {
					const char *iq_id = xmlnode_get_attrib(node, "id");
					if (iq_id != NULL && [self->_activeQueryID isEqualToString:@(iq_id)]) {
						AILog(@"AMPurpleJabberMAM: MAM query %s failed", iq_id);
						self->_mamQueryInProgress = NO;
						return;
					}
				}
			}

			// Only process message stanzas
			if (strcmp(node->name, "message") != 0) {
				return;
			}

			const char *queryID = NULL;

			// Check for MAM result: <message><result xmlns='urn:xmpp:mam:2'>...
			xmlnode *result = xmlnode_get_child_with_namespace(node, "result", NS_MAM.UTF8String);
			if (result) {
				queryID = xmlnode_get_attrib(result, "queryid");
				if (queryID && [self->_activeQueryID isEqualToString:@(queryID)]) {
					[self _handleResult:result];
					return;
				}
			}

			// Check for MAM fin: <message><fin xmlns='urn:xmpp:mam:2'>...
			xmlnode *fin = xmlnode_get_child_with_namespace(node, "fin", NS_MAM.UTF8String);
			if (fin) {
				queryID = xmlnode_get_attrib(fin, "queryid");
				if (queryID && [self->_activeQueryID isEqualToString:@(queryID)]) {
					[self _handleFin:fin];
					return;
				}
			}

		} @catch (NSException *e) {
			AILog(@"AMPurpleJabberMAM: Exception in received_data_cb: %@", e);
		}
	}
}

@implementation AMPurpleJabberMAM

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;

		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", (__bridge void *)self,
								  PURPLE_CALLBACK(AMPurpleJabberMAM_received_data_cb), (__bridge void *)self);
			AILog(@"AMPurpleJabberMAM: Connected to jabber-receiving-xmlnode signal");
		}
	}
	return self;
}

- (void)dealloc
{
	purple_signals_disconnect_by_handle((__bridge void *)self);
}

#pragma mark - Public

- (void)startSync
{
	// Check if MAM is enabled in account prefs
	PurpleAccount *pa = [_account purpleAccount];
	const char *enabled = purple_account_get_string(pa, KEY_MAM_ENABLED, "yes");
	_mamEnabled = (strcmp(enabled, "yes") == 0);

	if (!_mamEnabled) {
		AILog(@"AMPurpleJabberMAM: MAM is disabled for this account");
		return;
	}

	NSString *lastID = [self _loadLastArchiveID];
	if (lastID) {
		AILog(@"AMPurpleJabberMAM: Starting normal sync after archive ID %@", lastID);
		[self _sendQueryWithAfter:lastID];
	} else {
		AILog(@"AMPurpleJabberMAM: Starting first-run sync (last %d messages)", MAM_PAGE_SIZE);
		[self _sendQueryWithBefore];
	}
}

#pragma mark - Private: Query Building

- (void)_generateQueryID
{
	_activeQueryID = [NSString stringWithFormat:@"mam-%ld", (long)(++_queryCounter)];
}

- (void)_sendQueryWithAfter:(NSString *)after
{
	[self _generateQueryID];
	_mamQueryInProgress = YES;

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc == NULL) {
		AILog(@"AMPurpleJabberMAM: Connection gone, skipping MAM query (after)");
		_mamQueryInProgress = NO;
		return;
	}

	NSString *iq = [NSString stringWithFormat:@"<iq type='set' id='%@'>"
											   "<query xmlns='%@'>"
											   "<x xmlns='jabber:x:data' type='submit'>"
											   "<field var='FORM_TYPE' type='hidden'>"
											   "<value>%@</value>"
											   "</field>"
											   "</x>"
											   "<set xmlns='%@'>"
											   "<max>%d</max>"
											   "<after>%@</after>"
											   "</set>"
											   "</query>"
											   "</iq>",
											  self->_activeQueryID, NS_MAM, NS_MAM, NS_RSM, MAM_PAGE_SIZE, after];

	jabber_prpl_send_raw(gc, [iq UTF8String], -1);
}

- (void)_sendQueryWithBefore
{
	[self _generateQueryID];
	_mamQueryInProgress = YES;

	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc == NULL) {
		AILog(@"AMPurpleJabberMAM: Connection gone, skipping MAM query (before)");
		_mamQueryInProgress = NO;
		return;
	}

	NSString *iq = [NSString stringWithFormat:@"<iq type='set' id='%@'>"
											   "<query xmlns='%@'>"
											   "<x xmlns='jabber:x:data' type='submit'>"
											   "<field var='FORM_TYPE' type='hidden'>"
											   "<value>%@</value>"
											   "</field>"
											   "</x>"
											   "<set xmlns='%@'>"
											   "<max>%d</max>"
											   "<before/>"
											   "</set>"
											   "</query>"
											   "</iq>",
											  self->_activeQueryID, NS_MAM, NS_MAM, NS_RSM, MAM_PAGE_SIZE];

	jabber_prpl_send_raw(gc, [iq UTF8String], -1);
}

#pragma mark - Private: Result Handling

- (void)_handleResult:(xmlnode *)result
{
	// Extract <forwarded><message...>...</forwarded>
	xmlnode *forwarded = xmlnode_get_child_with_namespace(result, "forwarded", NS_FORWARD.UTF8String);
	if (!forwarded) {
		return;
	}

	// Extract timestamp from <delay xmlns='urn:xmpp:delay' stamp='...'>
	NSDate *timestamp = nil;
	xmlnode *delay = xmlnode_get_child_with_namespace(forwarded, "delay", NS_DELAY.UTF8String);
	if (delay) {
		const char *stamp = xmlnode_get_attrib(delay, "stamp");
		if (stamp) {
			timestamp = [self _parseStamp:stamp];
		}
	}
	if (!timestamp) {
		timestamp = [NSDate date];
	}

	// Extract archive ID from <result id='...'>
	const char *archiveID = xmlnode_get_attrib(result, "id");

	// Extract inner message
	xmlnode *msg = xmlnode_get_child(forwarded, "message");
	if (!msg) {
		return;
	}

	const char *from = xmlnode_get_attrib(msg, "from");
	NSString *fromJID = from ? @(from) : nil;
	const char *to = xmlnode_get_attrib(msg, "to");
	NSString *toJID = to ? @(to) : nil;

	// Extract body
	xmlnode *body = xmlnode_get_child(msg, "body");
	if (!body || !body->child || (body->child->type != XMLNODE_TYPE_DATA)) {
		return;
	}

	NSString *messageBody = [NSString stringWithUTF8String:body->child->data];
	if (![messageBody length]) {
		return;
	}

	[self _displayMessage:messageBody from:fromJID to:toJID date:timestamp];

	// Save archive ID for watermark tracking
	if (archiveID) {
		[self _saveLastArchiveID:@(archiveID)];
	}
}

- (void)_handleFin:(xmlnode *)fin
{
	_mamQueryInProgress = NO;

	const char *complete = xmlnode_get_attrib(fin, "complete");

	// If complete='true', we're done
	if (complete && strcmp(complete, "true") == 0) {
		AILog(@"AMPurpleJabberMAM: MAM query complete");
		return;
	}

	// More pages available - extract RSM <last> and continue
	xmlnode *set = xmlnode_get_child_with_namespace(fin, "set", NS_RSM.UTF8String);
	if (!set) {
		return;
	}

	xmlnode *last = xmlnode_get_child(set, "last");
	if (last && last->child && (last->child->type == XMLNODE_TYPE_DATA)) {
		NSString *lastID = @(last->child->data);
		[self _saveLastArchiveID:lastID];
		AILog(@"AMPurpleJabberMAM: Fetching next page after %@", lastID);
		[self _sendQueryWithAfter:lastID];
	}
}

#pragma mark - Private: Watermark Persistence

- (void)_saveLastArchiveID:(NSString *)archiveID
{
	if ([_lastArchiveID isEqualToString:archiveID]) {
		return;
	}

	_lastArchiveID = [archiveID copy];

	PurpleAccount *pa = [_account purpleAccount];
	purple_account_set_string(pa, KEY_LAST_ARCHIVE_ID, [archiveID UTF8String]);
}

- (NSString *)_loadLastArchiveID
{
	PurpleAccount *pa = [_account purpleAccount];
	const char *lastID = purple_account_get_string(pa, KEY_LAST_ARCHIVE_ID, NULL);
	if (lastID && strlen(lastID) > 0) {
		return @(lastID);
	}
	return nil;
}

#pragma mark - Private: Display

- (void)_displayMessage:(NSString *)body from:(NSString *)fromJID to:(NSString *)toJID date:(NSDate *)date
{
	if (!body) {
		return;
	}
	if (!fromJID && !toJID) {
		return;
	}

	// Determine direction: sentByMe when the from JID is the account's own JID
	NSString *userJID = [_account UID];
	NSString *fromBare = fromJID;
	NSRange slashRange = [fromJID rangeOfString:@"/"];
	if (slashRange.location != NSNotFound) {
		fromBare = [fromJID substringToIndex:slashRange.location];
	}
	BOOL sentByMe = (fromJID != nil && [fromBare isEqualToString:userJID]);

	// The chat partner is the other party (recipient for outgoing, sender for incoming)
	NSString *partnerJID = sentByMe ? toJID : fromJID;
	if (!partnerJID) {
		return;
	}

	// Strip resource from JID to get bare JID
	NSString *bareJID = partnerJID;
	slashRange = [partnerJID rangeOfString:@"/"];
	if (slashRange.location != NSNotFound) {
		bareJID = [partnerJID substringToIndex:slashRange.location];
	}

	// Only display in existing chats - don't create new ones
	AIChat *chat = [adium.chatController existingChatWithName:bareJID onAccount:_account];
	if (!chat) {
		return;
	}

	AIListContact *source = sentByMe ? (AIListContact *)_account : nil;
	AIListContact *dest = sentByMe ? nil : (AIListContact *)_account;

	if (!source) {
		source = [adium.contactController existingContactWithService:[_account service] account:_account UID:bareJID];
		if (!source) {
			source = (AIListContact *)_account;
		}
	}

	// Create attributed string
	NSAttributedString *attributedBody = [[NSAttributedString alloc] initWithString:body];

	AIContentMessage *content = [AIContentContext messageInChat:chat
													 withSource:source
													destination:dest
														   date:date
														message:attributedBody
													  autoreply:NO];

	[content setPostProcessContent:NO];
	[content setTrackContent:NO];
	[content setDisplayContentImmediately:NO];

	[adium.contentController displayContentObject:content usingContentFilters:YES immediately:YES];
}

#pragma mark - Private: Date Parsing

- (NSDate *)_parseStamp:(const char *)stamp
{
	if (!stamp) {
		return nil;
	}

	// Expected format: 2024-01-15T10:30:00Z or 2024-01-15T10:30:00.123Z
	NSString *stampStr = @(stamp);
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
	[formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];

	// Try with fractional seconds first
	[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
	NSDate *date = [formatter dateFromString:stampStr];
	if (!date) {
		[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
		date = [formatter dateFromString:stampStr];
	}
	if (!date) {
		[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
		date = [formatter dateFromString:stampStr];
	}
	if (!date) {
		[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
		date = [formatter dateFromString:stampStr];
	}

	return date;
}

@end
