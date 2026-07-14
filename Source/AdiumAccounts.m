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

#import "AdiumAccounts.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIService.h>

// Preference keys
#define TOP_ACCOUNT_ID @"TopAccountID" // Highest account object ID
#define ACCOUNT_LIST @"Accounts"       // Array of accounts
#define ACCOUNT_TYPE @"Type"           // Account type
#define ACCOUNT_SERVICE @"Service"     // Account service
#define ACCOUNT_UID @"UID"             // Account UID
#define ACCOUNT_OBJECT_ID @"ObjectID"  // Account object ID

@interface AdiumAccounts ()
- (void)_loadAccounts;
- (void)_saveAccounts;
- (NSString *)_generateUniqueInternalObjectID;
- (NSString *)_upgradeServiceUniqueID:(NSString *)serviceUniqueID forAccountDict:(NSDictionary *)accountDict;
- (void)upgradeAccounts;
@end

@interface AIAccount (SekretsIKnow)
@property(nonatomic, assign) AIService *service;
@end

/*!
 * @class AdiumAccounts
 * @brief Class to handle AIAccount access and creation
 *
 * This is a private class used by AIAccountController, its public interface.
 */
@implementation AdiumAccounts

- (id)init
{
	if ((self =
}

// Broadcast an account list changed notification
}
else if ([serviceID hasSuffix:@"LIBGAIM"])
{
	if ([serviceID isEqualToString:@"AIM-LIBGAIM"]) {
		NSString *uid = [accountDict objectForKey:ACCOUNT_UID];
		if (uid && [uid length]) {
			const char firstCharacter = [uid characterAtIndex:0];

			if ([uid hasSuffix:@"@mac.com"]) {
				serviceID = @"libpurple-oscar-Mac";
			} else if (firstCharacter >= '0' && firstCharacter <= '9') {
				serviceID = @"libpurple-oscar-ICQ";
			} else {
				serviceID = @"libpurple-oscar-AIM";
			}
		}
	} else if ([serviceID isEqualToString:@"GaduGadu-LIBGAIM"]) {
		serviceID = @"libpurple-Gadu-Gadu";
	} else if ([serviceID isEqualToString:@"Jabber-LIBGAIM"]) {
		serviceID = @"libpurple-Jabber";
	} else if ([serviceID isEqualToString:@"MSN-LIBGAIM"]) {
		serviceID = @"libpurple-MSN";
	} else if ([serviceID isEqualToString:@"Napster-LIBGAIM"]) {
		serviceID = @"libpurple-Napster";
	} else if ([serviceID isEqualToString:@"Novell-LIBGAIM"]) {
		serviceID = @"libpurple-GroupWise";
	} else if ([serviceID isEqualToString:@"Sametime-LIBGAIM"]) {
		serviceID = @"libpurple-Sametime";
	} else if ([serviceID isEqualToString:@"Yahoo-LIBGAIM"]) {
		serviceID = @"libpurple-Yahoo!";
	} else if ([serviceID isEqualToString:@"Yahoo-Japan-LIBGAIM"]) {
		serviceID = @"libpurple-Yahoo!-Japan";
	}
}
else if ([serviceID isEqualToString:@"rvous-libezv"]) serviceID = @"bonjour-libezv";
else if ([serviceID isEqualToString:@"joscar-OSCAR-AIM"]) serviceID = @"libpurple-oscar-AIM";
else if ([serviceID isEqualToString:@"joscar-OSCAR-dotMac"]) serviceID = @"libpurple-oscar-Mac";

return serviceID;
}

/*!
 * @brief Save accounts to disk
 */
- (void)_saveAccounts
{
	NSMutableArray *flatAccounts = [NSMutableArray array];
	AIAccount *account;

	// Build a flattened array of the accounts
	for (account in accounts) {
		if (![account isTemporary]) {
			NSMutableDictionary *flatAccount = [NSMutableDictionary dictionary];
			AIService *service = account.service;
			[flatAccount setObject:service.serviceCodeUniqueID forKey:ACCOUNT_TYPE];   // Unique plugin ID
			[flatAccount setObject:service.serviceID forKey:ACCOUNT_SERVICE];          // Shared service ID
			[flatAccount setObject:account.UID forKey:ACCOUNT_UID];                    // Account UID
			[flatAccount setObject:account.internalObjectID forKey:ACCOUNT_OBJECT_ID]; // Account Object ID

			[flatAccounts addObject:flatAccount];
		}
	}

	// Add any unloadable accounts so they're not lost
	[flatAccounts addObjectsFromArray:unloadableAccounts];

	// Save and broadcast an account list changed notification
	[adium.preferenceController setPreference:flatAccounts forKey:ACCOUNT_LIST group:PREF_GROUP_ACCOUNTS];
	[[NSNotificationCenter defaultCenter] postNotificationName:Account_ListChanged object:nil userInfo:nil];
}

/*!
 * @brief Perform upgrades for a new version
 *
 * 1.0: KEY_ACCOUNT_DISPLAY_NAME and @"textProfile" cleared if @"" and moved to global if identical on all accounts
 */
- (void)upgradeAccounts
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSNumber *upgradedAccounts = [userDefaults objectForKey:@"Adium:Account Prefs Upgraded for 1.0"];

	if (!upgradedAccounts || ![upgradedAccounts boolValue]) {
		[userDefaults setObject:[NSNumber numberWithBool:YES] forKey:@"Adium:Account Prefs Upgraded for 1.0"];

		AIAccount *account;
		NSEnumerator *enumerator, *keyEnumerator;
		NSString *key;

		// Adium 0.8x would store @"" in preferences which we now want to be able to inherit global values if they don't
		// have a value.
		NSSet *keysWeNowUseGlobally = [NSSet setWithObjects:KEY_ACCOUNT_DISPLAY_NAME, @"textProfile", nil];

		NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

		keyEnumerator = [keysWeNowUseGlobally objectEnumerator];
		while ((key = [keyEnumerator nextObject])) {
			NSAttributedString *firstAttributedString = nil;
			BOOL allOnThisKeyAreTheSame = YES;

			enumerator = [[self accounts] objectEnumerator];
			while ((account = [enumerator nextObject])) {
				NSAttributedString *attributedString =
					[[account preferenceForKey:key group:GROUP_ACCOUNT_STATUS] attributedString];
				if (attributedString && ![attributedString length]) {
					[account setPreference:nil forKey:key group:GROUP_ACCOUNT_STATUS];
					attributedString = nil;
				}

				if (attributedString) {
					if (firstAttributedString) {
						/* If this string is not the same as the first one we found, all are not the same.
						 * Only need to check if thus far they all have been the same
						 */
						if (allOnThisKeyAreTheSame &&
							![[[attributedString string]
								stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet]
								isEqualToString:
									[[firstAttributedString string]
										stringByTrimmingCharactersInSet:whitespaceAndNewlineCharacterSet]]) {
							allOnThisKeyAreTheSame = NO;
						}
					} else {
						// Note the first one we find, which will be our reference
						firstAttributedString = attributedString;
					}
				}
			}

			if (allOnThisKeyAreTheSame && firstAttributedString) {
				// All strings on this key are the same. Set the preference globally...
				[adium.preferenceController setPreference:[firstAttributedString dataRepresentation]
												   forKey:key
													group:GROUP_ACCOUNT_STATUS];

				// And remove it from all accounts
				enumerator = [[self accounts] objectEnumerator];
				while ((account = [enumerator nextObject])) {
					[account setPreference:nil forKey:key group:GROUP_ACCOUNT_STATUS];
				}
			}
		}

		[userDefaults synchronize];
	}
}

@end
