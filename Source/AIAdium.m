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

#import "AIAdium.h"
#import "AIAccountController.h"
#import "AIChatController.h"
#import "AIContactController.h"
#import "AIContentController.h"
#import "AICoreComponentLoader.h"
#import "AICorePluginLoader.h"
#import "AIURLHandlerPlugin.h"
// #import "AICrashController.h"
#import "AIDockController.h"
#import "AIEmoticonController.h"
// #import "AIExceptionController.h"
#import "AIAddressBookController.h"
#import "AIAppearancePreferences.h"
#import "AIInterfaceController.h"
#import "AILoginController.h"
#import "AIMenuController.h"
#import "AIPreferenceController.h"
#import "AISoundController.h"
#import "AIStatusController.h"
#import "AIToolbarController.h"
#import "AIXtrasManager.h"
#import "AdiumSetupWizard.h"
#import "ESAddressBookIntegrationAdvancedPreferences.h"
#import "ESApplescriptabilityController.h"
#import "ESContactAlertsController.h"
#import "ESDebugController.h"
#import "ESFileTransferController.h"
#import "ESTextAndButtonsWindowController.h"
#import "LNAboutBoxController.h"
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AISharedWriterQueue.h>
#import <Adium/AIContactHidingController.h>
#import <Adium/AIListContact.h>
#import <Adium/AIPathUtilities.h>
#import <Adium/AIService.h>
#import <Adium/AdiumAuthorization.h>
#import <Sparkle/Sparkle.h>
#import <sys/sysctl.h>

#define ADIUM_TRAC_PAGE @"https://github.com/phaedrus1992/adiumy"
#define ADIUM_CONTRIBUTE_PAGE @"https://github.com/phaedrus1992/adiumy/blob/main/CONTRIBUTING.md"
#define ADIUM_DONATE_PAGE @"https://github.com/sponsors/phaedrus1992"
#define ADIUM_REPORT_BUG_PAGE @"https://github.com/phaedrus1992/adiumy/issues/new"
#define ADIUM_FORUM_PAGE @"https://github.com/phaedrus1992/adiumy/discussions"
#define ADIUM_FEEDBACK_PAGE @"https://github.com/phaedrus1992/adiumy/issues/new"

#if defined(BETA_RELEASE)
#define ADIUM_VERSION_HISTORY_PAGE @"https://github.com/phaedrus1992/adiumy/releases"
#else
#define ADIUM_VERSION_HISTORY_PAGE @"https://github.com/phaedrus1992/adiumy/releases"
#endif

// Portable Adium prefs key
#define PORTABLE_ADIUM_KEY @"Preference Folder Location"

#define ALWAYS_RUN_SETUP_WIZARD FALSE

#define AIEarliestLaunchedAdiumVersionKey @"AIEarliestLaunchedAdiumVersion"

static NSString *prefsCategory;

@interface AIAdium ()
- (void)completeLogin;
- (void)openAppropriatePreferencesIfNeeded;
- (void)deleteTemporaryFiles;

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)systemTimeZoneDidChange:(NSNotification *)inNotification;
- (void)confirmQuitQuestion:(NSNumber *)number userInfo:(id)info suppression:(NSNumber *)suppressed;
- (void)fileTransferQuitQuestion:(NSNumber *)number userInfo:(id)info suppression:(NSNumber *)suppressed;
- (void)openChatQuitQuestion:(NSNumber *)number userInfo:(id)info suppression:(NSNumber *)suppressed;
- (void)unreadQuitQuestion:(NSNumber *)number userInfo:(id)info suppression:(NSNumber *)suppressed;
@end

@implementation AIAdium

- (id)init
{
	if ((self = 
			[s setString:character];
}
else
{
	// Add character to string and continue
	[s appendString:character];
}
oldType = newType;
}

// Add the last part onto the array
[parts addObject:[NSString stringWithString:s]];
return parts;
}

- (NSComparisonResult)compareVersion:(NSString *)appVersion toVersion:(NSString *)appcastVersion;
{
	/*********** Adium Changes **********/
	NSRange debugRange = [appVersion rangeOfString:@"-debug"];
	if (debugRange.location != NSNotFound)
		appVersion = [appVersion substringToIndex:debugRange.location];

	NSRange hgOurs = [appVersion rangeOfString:@"hg"];
	NSRange hgTheirs = [appcastVersion rangeOfString:@"hg"];
	NSRange svnOurs = [appVersion rangeOfString:@"svn"];
	NSRange svnTheirs = [appcastVersion rangeOfString:@"svn"];

	if (hgOurs.location != NSNotFound && svnTheirs.location != NSNotFound)
		return NSOrderedDescending;
	if (hgTheirs.location != NSNotFound && svnOurs.location != NSNotFound)
		return NSOrderedAscending;

	/*********** End Adium Changes *******/

	NSArray *partsA = [self splitVersionString:appVersion];
	NSArray *partsB = [self splitVersionString:appcastVersion];

	NSString *partA, *partB;
	NSInteger i, n, typeA, typeB, intA, intB;

	n = MIN([partsA count], [partsB count]);
	for (i = 0; i < n; ++i) {
		partA = [partsA objectAtIndex:i];
		partB = [partsB objectAtIndex:i];

		typeA = [self typeOfCharacter:partA];
		typeB = [self typeOfCharacter:partB];

		// Compare types
		if (typeA == typeB) {
			// Same type; we can compare
			if (typeA == kNumberType) {
				intA = [partA intValue];
				intB = [partB intValue];
				if (intA > intB) {
					return NSOrderedDescending;
				} else if (intA < intB) {
					return NSOrderedAscending;
				}
			} else if (typeA == kStringType) {
				NSComparisonResult result = [partA compare:partB];
				if (result != NSOrderedSame) {
					return result;
				}
			}
		} else {
			// Not the same type? Now we have to do some validity checking
			if (typeA != kStringType && typeB == kStringType) {
				// typeA wins
				return NSOrderedDescending;
			} else if (typeA == kStringType && typeB != kStringType) {
				// typeB wins
				return NSOrderedAscending;
			} else {
				// One is a number and the other is a period. The period is invalid
				if (typeA == kNumberType) {
					return NSOrderedDescending;
				} else {
					return NSOrderedAscending;
				}
			}
		}
	}
	// The versions are equal up to the point where they both still have parts
	// Lets check to see if one is larger than the other
	if ([partsA count] != [partsB count]) {
		// Yep. Lets get the next part of the larger
		// n holds the index of the part we want.
		NSString *missingPart;
		SUCharacterType missingType;
		NSComparisonResult shorterResult, largerResult;

		if ([partsA count] > [partsB count]) {
			missingPart = [partsA objectAtIndex:n];
			shorterResult = NSOrderedAscending;
			largerResult = NSOrderedDescending;
		} else {
			missingPart = [partsB objectAtIndex:n];
			shorterResult = NSOrderedDescending;
			largerResult = NSOrderedAscending;
		}

		missingType = [self typeOfCharacter:missingPart];
		// Check the type
		if (missingType == kStringType) {
			// It's a string. Shorter version wins
			return shorterResult;
		} else {
			// It's a number/period. Larger version wins
			return largerResult;
		}
	}

	// The 2 strings are identical
	return NSOrderedSame;
}

@end

@implementation NSObject (AdiumAccess)
- (NSObject<AIAdium> *)adium
{
	return adium;
}
@end
