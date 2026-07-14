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

#import "ESOTRUnknownFingerprintController.h"
#import "AIHTMLDecoder.h"
#import "ESTextAndButtonsWindowController.h"
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>

#import "AdiumOTREncryption.h"

@interface ESOTRUnknownFingerprintController ()
+ (void)showFingerprintPromptWithMessageString:(NSString *)messageString
								  acceptButton:(NSString *)acceptButton
									denyButton:(NSString *)denyButton
								  responseInfo:(NSDictionary *)responseInfo;
+ (void)unknownFingerprintResponseInfo:(NSDictionary *)responseInfo wasAccepted:(BOOL)fingerprintAccepted;
@end

@implementation ESOTRUnknownFingerprintController

+ (void)showUnknownFingerprintPromptWithResponseInfo:(NSDictionary *)responseInfo
{
	NSString *messageString;
	AIAccount *account = 
						   target:self
						 userInfo:nil];
	[textAndButtonsWindowController showOnWindow:window];

	// Don't close the original window if the help button is pressed
	shouldCloseWindow = NO;
}
else
{
	fingerprintAccepted = ((returnCode == AITextAndButtonsDefaultReturn) ? YES : NO);

	[self unknownFingerprintResponseInfo:userInfo wasAccepted:fingerprintAccepted];
}
}

return shouldCloseWindow;
}

+ (void)unknownFingerprintResponseInfo:(NSDictionary *)responseInfo wasAccepted:(BOOL)fingerprintAccepted
{
	AIAccount *account = [responseInfo objectForKey:@"AIAccount"];
	NSString *who = [responseInfo objectForKey:@"who"];

	ConnContext *context =
		otrl_context_find(otrg_get_userstate(), [who UTF8String], [account.internalObjectID UTF8String],
						  [account.service.serviceCodeUniqueID UTF8String], 0, NULL, NULL, NULL);
	Fingerprint *fprint;
	BOOL oldtrust;

	if (context == NULL) {
		AILog(@"Warning: ESOTRUnknownFingerprintController: NULL context for %@", responseInfo);
		return;
	}

	fprint = context->active_fingerprint;

	if (fprint == NULL) {
		AILog(@"Warning: ESOTRUnknownFingerprintController: NULL fprint for %@", responseInfo);
		return;
	}

	oldtrust = (fprint->trust && fprint->trust[0]);

	/* See if anything's changed */
	if (fingerprintAccepted != oldtrust) {
		otrl_context_set_trust(fprint, fingerprintAccepted ? "verified" : "");
		// Write the new info to disk, redraw the UI
		otrg_plugin_write_fingerprints();
		otrg_ui_update_keylist();
	}
}

@end
