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

#import "AIURLHandlerPlugin.h"
#import "AIURLHandlerAdvancedPreferences.h"

#import "AINewContactWindowController.h"
#import "XtrasInstaller.h"

#import "AITemporaryIRCAccountWindowController.h"

#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIURLAdditions.h>
#import <AIUtilities/AIWindowAdditions.h>

#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIService.h>

@interface AIURLHandlerPlugin ()
- (void)checkHandledSchemes;

- (void)handleURL:(NSNotification *)notification;

- (void)_openChatToContactWithName:(NSString *)name
						 onService:(NSString *)serviceIdentifier
					   withMessage:(NSString *)body;
- (void)_openAIMGroupChat:(NSString *)roomname onExchange:(NSInteger)exchange;
- (void)_openXMPPGroupChat:(NSString *)name onServer:(NSString *)server withPassword:(NSString *)inPassword;
- (void)_openIRCGroupChat:(NSString *)name
				 onServer:(NSString *)server
				 withPort:(NSInteger)port
			  andPassword:(NSString *)password;
@end

/*!
 * @class AIURLHandlerPlugin
 *
 * The URL handler plugin handles URL events sent to us.
 *
 * For example, it will convert aim://goim?sn=fuark to open a chat window with
 * the user "fuark" on the first available AIM account.
 *
 * This plugin is also responsible for managing the default application settings
 * for the schemes we support, and enforcing if necessary our ownership.
 */
@implementation AIURLHandlerPlugin
/*!
 * @brief Install plugin
 *
 * This sets up our advanced preferences view and checks our defaults.
 */
- (void)installPlugin
{
	preferences =

		// Should prompt for where to apply the icon?
		if (imageData && [[NSImage alloc] initWithData:imageData])
	{
		// If we successfully got image data, and that data makes a valid NSImage, set it as our global
		// buddy icon
		[adium.preferenceController setPreference:imageData forKey:KEY_USER_ICON group:GROUP_ACCOUNT_STATUS];
	}
}
}
}
else if ([scheme isEqualToString:@"ymsgr"])
{
	if ([host caseInsensitiveCompare:@"sendim"] == NSOrderedSame) {
		// ymsgr://sendim?tekjew
		NSString *name = [[[url query] stringByDecodingURLEscapes] compactedString];

		if (name) {
			[self _openChatToContactWithName:name onService:serviceID withMessage:nil];
		}

	} else if ([host caseInsensitiveCompare:@"im"] == NSOrderedSame) {
		// ymsgr://im?to=tekjew
		NSString *name = [[[url queryArgumentForKey:@"to"] stringByDecodingURLEscapes] compactedString];

		if (name) {
			[self _openChatToContactWithName:name onService:serviceID withMessage:nil];
		}
	}
}
else if ([scheme isEqualToString:@"gtalk"])
{
	if ([url queryArgumentForKey:@"openChatToScreenName"]) {
		// gtalk:chat?jid=foo@gmail.com&from_jid=bar@gmail.com
		NSString *name = [[[url queryArgumentForKey:@"jid"] stringByDecodingURLEscapes] compactedString];

		if (name) {
			[self _openChatToContactWithName:name onService:serviceID withMessage:nil];
		}
	}
}
else if ([scheme isEqualToString:@"xmpp"])
{
	if ([query rangeOfString:@"message"].location == 0) {
		// xmpp:johndoe@jabber.org?message;subject=Subject;body=Body
		// xmpp:jabber.org?message;subject=Subject;body=Body
		NSString *msg = [[url queryArgumentForKey:@"body"] stringByDecodingURLEscapes];

		if ([url user]) {
			[self _openChatToContactWithName:[NSString stringWithFormat:@"%@@%@", [url user], [url host]]
								   onService:serviceID
								 withMessage:msg];
		} else {
			[self _openChatToContactWithName:[url host] onService:serviceID withMessage:msg];
		}
	} else if ([query rangeOfString:@"roster"].location == 0 || [query rangeOfString:@"subscribe"].location == 0) {
		// xmpp:johndoe@jabber.org?roster;name=John%20Doe;group=Friends
		// xmpp:johndoe@jabber.org?subscribe

		// Group specification and name specification is currently ignored,
		// due to limitations in the AINewContactWindowController API.

		AIService *jabberService;

		jabberService = [adium.accountController firstServiceWithServiceID:@"Jabber"];

		AINewContactWindowController *newContactWindowController = [[AINewContactWindowController alloc]
			initWithContactName:[NSString stringWithFormat:@"%@@%@", [url user], [url host]]
						service:jabberService
						account:nil];
		[newContactWindowController showOnWindow:nil];
	} else if ([query rangeOfString:@"remove"].location == 0 || [query rangeOfString:@"unsubscribe"].location == 0) {
		// xmpp:johndoe@jabber.org?remove
		// xmpp:johndoe@jabber.org?unsubscribe

	} else if ([query rangeOfString:@"join"].location == 0) {
		NSString *password = [[url queryArgumentForKey:@"password"] stringByDecodingURLEscapes];

		[self _openXMPPGroupChat:[url user] onServer:[url host] withPassword:password];

		// TODO:
	}
}
else if ([scheme caseInsensitiveCompare:@"irc"] == NSOrderedSame)
{
	// irc://server:port/channel?password
	NSString *channelName = [url fragment];
	NSNumber *portNumber = [url port];
	NSInteger port;

	if (!channelName.length && (!url.path.lastPathComponent || [url.path.lastPathComponent isEqualToString:@"/"])) {
		channelName = @"#";
	} else if (!channelName.length) {
		channelName = url.path.lastPathComponent;
	}

	if (![channelName hasPrefix:@"#"] && ![channelName hasPrefix:@"&"]) {
		channelName = [@"#" stringByAppendingString:channelName];
	}

	if (portNumber == nil) {
		port = -1;
	} else {
		port = [portNumber integerValue];
	}

	if (!host) {
		host = @"";
	}

	channelName = [channelName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

	[self _openIRCGroupChat:channelName onServer:host withPort:port andPassword:[url query]];
}
else if ([scheme caseInsensitiveCompare:@"msim"] == NSOrderedSame)
{
	NSString *contactName = [url queryArgumentForKey:@"cID"];

	if (contactName.length) {
		if ([host isEqualToString:@"addContact"]) {
			AINewContactWindowController *newContactWindowController = [[AINewContactWindowController alloc]
				initWithContactName:contactName
							service:[adium.accountController firstServiceWithServiceID:serviceID]
							account:nil];
			[newContactWindowController showOnWindow:nil];
		} else if ([host isEqualToString:@"sendIM"]) {
			[self _openChatToContactWithName:contactName onService:serviceID withMessage:nil];
		}
	}
}
else
{
	// Default to opening the host as a name.
	NSString *user = [url user];
	NSString *ircHost = [url host];
	NSString *name;
	if (user && [user length]) {
		// jabber://tekjew@jabber.org
		name = [NSString stringWithFormat:@"%@@%@", [url user], [url host]];
	} else {
		// aim://tekjew
		name = ircHost;
	}

	[self _openChatToContactWithName:[name compactedString] onService:serviceID withMessage:nil];
}
}
else if ([scheme isEqualToString:@"adiumyextra"])
{
	// Installs an adium extra
	//  adiumyextra://github.com/phaedrus1992/adiumy/path/to/xtra.zip

	[[XtrasInstaller installer] installXtraAtURL:url];
}
}

#pragma mark Chat openers

- (void)_openChatToContactWithName:(NSString *)UID onService:(NSString *)serviceID withMessage:(NSString *)message
{
	AIListContact *contact = [adium.contactController preferredContactWithUID:UID
																 andServiceID:serviceID
														forSendingContentType:CONTENT_MESSAGE_TYPE];
	if (contact) {
		// Open the chat and set it as active
		[adium.interfaceController setActiveChat:[adium.chatController openChatWithContact:contact
																		onPreferredAccount:YES]];

		// Insert the message text as if the user had typed it after opening the chat
		NSResponder *responder = [[NSApp keyWindow] earliestResponderOfClass:[NSTextView class]];
		if (message && [responder isKindOfClass:[NSTextView class]] && [(NSTextView *)responder isEditable]) {
			[responder insertText:message];
		}

	} else {
		NSBeep();
	}
}

- (void)_openIRCGroupChat:(NSString *)name
				 onServer:(NSString *)server
				 withPort:(NSInteger)port
			  andPassword:(NSString *)password
{
	AIAccount *ircAccount = nil;

	for (AIAccount *account in adium.accountController.accounts) {
		if ([account.service.serviceClass isEqualToString:@"IRC"] && [account.host isEqualToString:server] &&
			(port == -1 || account.port == port)) {
			ircAccount = account;
			break;
		}
	}

	if (!ircAccount) {
		AITemporaryIRCAccountWindowController *temporaryIRCAccountWindowController =
			[[AITemporaryIRCAccountWindowController alloc] initWithChannel:name
																	server:server
																	  port:port
															   andPassword:password];
		[temporaryIRCAccountWindowController show];
	} else if (name) {
		[adium.chatController
				chatWithName:name
				  identifier:nil
				   onAccount:ircAccount
			chatCreationInfo:[NSDictionary dictionaryWithObjectsAndKeys:name, @"channel", password,
																		@"password", /* may be nil, so should be last */
																		nil]];
	} else {
		NSBeep();
	}
}

- (void)_openXMPPGroupChat:(NSString *)name onServer:(NSString *)server withPassword:(NSString *)password
{
	AIAccount *account = nil;

	// Find an XMPP-compatible online account which can create group chats
	for (account in adium.accountController.accounts) {
		if (account.online && [account.service.serviceClass isEqualToString:@"Jabber"] &&
			[account.service canCreateGroupChats]) {
			break;
		}
	}

	if (name && account) {
		[adium.chatController
				chatWithName:[NSString stringWithFormat:@"%@@%@", name, server]
				  identifier:nil
				   onAccount:account
			chatCreationInfo:[NSDictionary dictionaryWithObjectsAndKeys:name, @"room", server, @"server",
																		account.displayName, @"handle", password,
																		@"password", /* may be nil, so should be last */
																		nil]];
	} else {
		NSBeep();
	}
}

- (void)_openAIMGroupChat:(NSString *)roomname onExchange:(NSInteger)exchange
{
	AIAccount *account;

	// Find an AIM-compatible online account which can create group chats
	for (account in adium.accountController.accounts) {
		if (account.online && [account.service.serviceClass isEqualToString:@"AIM-compatible"] &&
			[account.service canCreateGroupChats]) {
			break;
		}
	}

	if (roomname && account) {
		[adium.chatController
				chatWithName:roomname
				  identifier:nil
				   onAccount:account
			chatCreationInfo:[NSDictionary dictionaryWithObjectsAndKeys:roomname, @"room",
																		[NSNumber numberWithInteger:exchange],
																		@"exchange", nil]];
	} else {
		NSBeep();
	}
}

@end
