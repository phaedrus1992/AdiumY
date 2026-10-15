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

#import "AMPurpleJabberCSI.h"
#import "CBPurpleAccount.h"
#import "ESPurpleJabberAccount.h"
#import <AdiumY/AIAdiumProtocol.h>
#import <libpurple/jabber.h>

#define NS_CSI @"urn:xmpp:csi:0"
#define NS_DISCO_INFO @"http://jabber.org/protocol/disco#info"

/* The id of the query that asks the server for its features. The reply carries
 * the same id, which is how the answer is recognized. */
#define CSI_DISCO_QUERY_ID @"adiumy-csi-disco"

#define AMPurpleJabberCSIStateUnknown 0
#define AMPurpleJabberCSIStateActive 1
#define AMPurpleJabberCSIStateInactive 2

@interface AMPurpleJabberCSI () {
	BOOL _csiEnabled;
}

/// Build the CSI stanza XML string for the given state.
///
/// @param state AMPurpleJabberCSIStateActive (1) or AMPurpleJabberCSIStateInactive (2)
/// @return An XML string appropriate for jabber_prpl_send_raw
- (NSString *)_xmlForState:(NSInteger)state;

/// Ask the server for its features, and enable CSI if it lists CSI.
- (void)_requestSupport;

/// Send the CSI enable handshake element.
- (void)_sendEnable;

/// Construct and send a CSI state stanza.
///
/// @param state AMPurpleJabberCSIStateActive or AMPurpleJabberCSIStateInactive
- (void)_sendState:(NSInteger)state;

@end

@implementation AMPurpleJabberCSI

+ (void)initialize
{
	if (self == [AMPurpleJabberCSI class]) {
		jabber_add_feature([NS_CSI UTF8String], NULL);
	}
}

- (id)initWithAccount:(ESPurpleJabberAccount *)account
{
	if ((self = [super init])) {
		_account = account;
		_currentState = AMPurpleJabberCSIStateUnknown;
		_csiEnabled = NO;

		// Observe app foreground/background transitions
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appDidBecomeActiveNotification:)
													 name:NSApplicationDidBecomeActiveNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appWillResignActiveNotification:)
													 name:NSApplicationWillResignActiveNotification
												   object:nil];

		// Observe account connection
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(accountConnected:)
													 name:ACCOUNT_CONNECTED
												   object:_account];

		// Intercept CSI enable handshake response (<enabled/>)
		PurplePlugin *jabber = purple_find_prpl("prpl-jabber");
		if (jabber) {
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", (__bridge void *)self,
								  PURPLE_CALLBACK(AMPurpleJabberCSI_received_xmlnode_cb), (__bridge void *)self);
		}
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	purple_signals_disconnect_by_handle((__bridge void *)self);
}

#pragma mark - Notifications

- (void)appDidBecomeActiveNotification:(NSNotification *)notification
{
	[self refreshState];
}

- (void)appWillResignActiveNotification:(NSNotification *)notification
{
	[self refreshState];
}

- (void)accountConnected:(NSNotification *)notification
{
	// A new stream starts with this connection, so the server has not enabled
	// CSI yet even if the previous connection did.
	_csiEnabled = NO;
	_currentState = AMPurpleJabberCSIStateUnknown;

	[self _requestSupport];
}

#pragma mark - CSI

- (void)refreshState
{
	BOOL isActive = [[NSApplication sharedApplication] isActive];
	if (isActive) {
		if (_currentState != AMPurpleJabberCSIStateActive) {
			[self _sendState:AMPurpleJabberCSIStateActive];
		}
	} else {
		if (_currentState != AMPurpleJabberCSIStateInactive) {
			[self _sendState:AMPurpleJabberCSIStateInactive];
		}
	}
}

#pragma mark - Private

- (NSString *)_xmlForState:(NSInteger)state
{
	NSString *childElement = (state == AMPurpleJabberCSIStateActive) ? @"active" : @"inactive";
	return [NSString stringWithFormat:@"<%@ xmlns='%@'/>", childElement, NS_CSI];
}

/// Ask the server for its features.
///
/// The reply carries the same id, and the callback sends the enable element
/// when the server lists CSI (#401).
- (void)_requestSupport
{
	NSString *xml = [NSString
		stringWithFormat:@"<iq type='get' id='%@'><query xmlns='%@'/></iq>", CSI_DISCO_QUERY_ID, NS_DISCO_INFO];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		AILog(@"AMPurpleJabberCSI: Asked the server whether it supports CSI");
	}
}

/// Send the CSI enable handshake element.
- (void)_sendEnable
{
	NSString *xml = [NSString stringWithFormat:@"<enable xmlns='%@'/>", NS_CSI];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		_csiEnabled = NO;
		AILog(@"AMPurpleJabberCSI: Sent CSI enable request");
	}
}

- (void)_sendState:(NSInteger)state
{
	// Per XEP-0352 §3.3, no state element is valid before the server answers
	// the enable request with <enabled/>. A server without CSI support never
	// answers, so this also keeps the state elements off that stream (#401).
	if (!_csiEnabled) {
		AILog(@"AMPurpleJabberCSI: Skipping <%@/> — CSI not enabled",
			  (state == AMPurpleJabberCSIStateActive) ? @"active" : @"inactive");
		return;
	}

	NSString *xml = [self _xmlForState:state];
	PurpleAccount *pa = [_account purpleAccount];
	PurpleConnection *gc = purple_account_get_connection(pa);
	if (gc) {
		jabber_prpl_send_raw(gc, [xml UTF8String], -1);
		_currentState = state;
		AILog(@"AMPurpleJabberCSI: Sent %@ state", (state == AMPurpleJabberCSIStateActive) ? @"active" : @"inactive");
	}
}

#pragma mark - C Callbacks

/* The domain part of a JID: no node, no resource. */
static NSString *AMPurpleJabberCSI_domain(NSString *jid)
{
	NSRange at = [jid rangeOfString:@"@" options:NSBackwardsSearch];
	NSString *host = (at.location == NSNotFound) ? jid : [jid substringFromIndex:NSMaxRange(at)];
	NSRange slash = [host rangeOfString:@"/"];
	return (slash.location == NSNotFound) ? host : [host substringToIndex:slash.location];
}

/* True when the stanza came from this account's own server. A stanza with no
 * from attribute came over the connection itself, which is the server too. */
static BOOL AMPurpleJabberCSI_from_own_server(NSString *uid, xmlnode *node)
{
	const char *from = xmlnode_get_attrib(node, "from");
	if (!from || !*from) {
		return YES;
	}

	NSString *senderDomain = [AMPurpleJabberCSI_domain([NSString stringWithUTF8String:from]) lowercaseString];
	NSString *serverDomain = [AMPurpleJabberCSI_domain(uid) lowercaseString];
	return [senderDomain isEqualToString:serverDomain];
}

/* True when the node is the answer to the feature query and it lists CSI. */
static BOOL AMPurpleJabberCSI_is_disco_reply_with_csi(xmlnode *node)
{
	const char *identifier = xmlnode_get_attrib(node, "id");
	const char *type = xmlnode_get_attrib(node, "type");
	if (!identifier || strcmp(identifier, [CSI_DISCO_QUERY_ID UTF8String]) != 0) {
		return NO;
	}
	if (!type || strcmp(type, "result") != 0) {
		return NO;
	}

	for (xmlnode *child = node->child; child; child = child->next) {
		if (strcmp(child->name, "query") != 0) {
			continue;
		}
		for (xmlnode *feature = child->child; feature; feature = feature->next) {
			if (strcmp(feature->name, "feature") != 0) {
				continue;
			}
			const char *variable = xmlnode_get_attrib(feature, "var");
			if (variable && strcmp(variable, [NS_CSI UTF8String]) == 0) {
				return YES;
			}
		}
	}

	return NO;
}

static void AMPurpleJabberCSI_received_xmlnode_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {
		@try {
			AMPurpleJabberCSI *self = (__bridge AMPurpleJabberCSI *)data;
			xmlnode *node = *packet;
			if (!node || !gc || !self) {
				return;
			}

			// The signal belongs to the prpl, so it fires for every Jabber
			// connection. Act only on stanzas from this account's own stream.
			PurpleAccount *pa = [self->_account purpleAccount];
			if (pa == NULL || gc != purple_account_get_connection(pa)) {
				return;
			}

			NSString *uid = [self->_account UID];
			if (strcmp(node->name, "enabled") == 0) {
				const char *xmlns = xmlnode_get_namespace(node);
				if (xmlns && strcmp(xmlns, [NS_CSI UTF8String]) == 0 && AMPurpleJabberCSI_from_own_server(uid, node)) {
					self->_csiEnabled = YES;
					AILog(@"AMPurpleJabberCSI: Server enabled CSI");
					[self _sendState:AMPurpleJabberCSIStateActive];
				}

			} else if (strcmp(node->name, "iq") == 0) {
				const char *identifier = xmlnode_get_attrib(node, "id");
				BOOL isOurReply = identifier && strcmp(identifier, [CSI_DISCO_QUERY_ID UTF8String]) == 0;
				if (isOurReply && AMPurpleJabberCSI_from_own_server(uid, node)) {
					if (AMPurpleJabberCSI_is_disco_reply_with_csi(node)) {
						[self _sendEnable];
					} else {
						const char *type = xmlnode_get_attrib(node, "type");
						if (type && strcmp(type, "error") == 0) {
							// The reply names its own cause; report that instead of a
							// capability claim.
							const char *errorType = NULL;
							const char *condition = NULL;
							xmlnode *error = xmlnode_get_child(node, "error");
							if (error) {
								errorType = xmlnode_get_attrib(error, "type");
								for (xmlnode *child = error->child; child; child = child->next) {
									if (strcmp(child->name, "text") != 0) {
										condition = child->name;
										break;
									}
								}
							}
							AILog(@"AMPurpleJabberCSI: The feature query failed (%s: %s)",
								  errorType ? errorType : "unknown", condition ? condition : "unknown");
						} else {
							AILog(@"AMPurpleJabberCSI: Server does not support CSI");
						}
					}
				}
			}
		} @catch (NSException *e) {
			AILog(@"AMPurpleJabberCSI: Exception in received_xmlnode_cb: %@: %@", e.name, e.reason);
		}
	}
}

@end
