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

#import "AITemporaryIRCAccountWindowController.h"

#import "AIEditAccountWindowController.h"
#import "AIServiceMenu.h"
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIStringFormatter.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIService.h>

@implementation AITemporaryIRCAccountWindowController

/*!
 * @brief Prompt for adding a new (temporary) IRC account after the user clicked an irc://-link.
 *
 * @param newChannel The channel part of the IRC link
 * @param newServer The server part of the link
 * @param newPort The port number of the link, or -1 if no port number specified (will assume 6667)
 * @param newPassword The password part of the link. This is the password of the channel, _not_ the password of the
 * account!
 */
- (id)initWithChannel:(NSString *)newChannel
			   server:(NSString *)newServer
				 port:(NSInteger)newPort
		  andPassword:(NSString *)newPassword
{
	if ((self = 
		account = inAccount;
}

// Make sure our UID is still accurate
if (![inAccount.UID isEqualToString:self.UID]) {
	[textField_name setStringValue:inAccount.UID];
}

if (![inAccount.host isEqualToString:[self host]]) {
	[textField_server setStringValue:inAccount.host];
}
}

- (void)accountConnected:(NSNotification *)not
{
	[adium.chatController
			chatWithName:channel
			  identifier:nil
			   onAccount:account
		chatCreationInfo:[NSDictionary dictionaryWithObjectsAndKeys:channel, @"channel", password,
																	@"password", /* may be nil, so should be last */
																	nil]];

	[[self window] performClose:nil];
}

@end
