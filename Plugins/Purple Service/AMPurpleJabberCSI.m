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
#import <Adium/AIAdiumProtocol.h>
#import <libpurple/jabber.h>

#define NS_CSI @"urn:xmpp:csi:0"

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
			purple_signal_connect(jabber, "jabber-receiving-xmlnode", self,
								  PURPLE_CALLBACK(AMPurpleJabberCSI_received_xmlnode_cb), (__bridge void *)self);
		}
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	purple_signals_disconnect_by_handle((__bridge void *)self);

	[super dealloc];
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
	[self _sendEnable];
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
	// Per XEP-0352 §3.3: don't send <inactive/> until CSI is enabled
	if (state == AMPurpleJabberCSIStateInactive && !_csiEnabled) {
		AILog(@"AMPurpleJabberCSI: Skipping <inactive/> — CSI not yet enabled");
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

static void AMPurpleJabberCSI_received_xmlnode_cb(PurpleConnection *gc, xmlnode **packet, gpointer data)
{
	@autoreleasepool {
		@try {
			AMPurpleJabberCSI *self = (__bridge AMPurpleJabberCSI *)data;
			xmlnode *node = *packet;
			if (!node || !gc || !self) {
				return;
			}
			if (strcmp(node->name, "enabled") == 0) {
				const char *xmlns = xmlnode_get_namespace(node);
				if (xmlns && strcmp(xmlns, [NS_CSI UTF8String]) == 0) {
					self->_csiEnabled = YES;
					AILog(@"AMPurpleJabberCSI: Server enabled CSI");
					[self _sendState:AMPurpleJabberCSIStateActive];
				}
			}
		} @catch (NSException *e) {
			AILog(@"AMPurpleJabberCSI: Exception in received_xmlnode_cb: %@: %@", e.name, e.reason);
		}
	}
}

@end
