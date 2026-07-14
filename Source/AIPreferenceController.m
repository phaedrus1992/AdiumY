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

#import "AIPreferenceController.h"

#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContactObserverManager.h>
#import <Adium/AILoginControllerProtocol.h>
#import <Adium/AIToolbarControllerProtocol.h>

#import "AIAdvancedPreferencePane.h"
#import "AIPreferenceContainer.h"
#import "AIPreferencePane.h"
#import "AIPreferenceWindowController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <Adium/AIListObject.h>

#define TITLE_OPEN_PREFERENCES AILocalizedString(@"Open Preferences", nil)

#define LOADED_OBJECT_PREFS_KEY @"Loaded individual object & account prefs"
#define PREFS_GROUP @"Preferences"

@interface AIPreferenceController ()
- (AIPreferenceContainer *)preferenceContainerForGroup:(NSString *)group object:(AIListObject *)object;
- (void)upgradeToSingleObjectPrefsDictIfNeeded;
@end

/*!
 * @class AIPreferenceController
 * @brief Preference Controller
 *
 * Handles loading and saving preferences, default preferences, and preference changed notifications
 */
@implementation AIPreferenceController

/*!
 * @brief Initialize
 */
- (id)init
{
	if ((self =
}
}

/*!
 * @brief Set if preference changed notifications should be delayed
 *
 * Changing large amounts of preferences at once causes a lot of notification overhead. This should be used like
 *
				}
			}
		}

		NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
		if ([searchPaths count]) {
			userPreferredDownloadFolder = [searchPaths objectAtIndex:0];
		}
	}

	/* If we can't write to the specified folder, fall back to the desktop and then to the home directory;
	 * if neither are writable the user has worse problems then an IM download to worry about.
	 */
if (![[NSFileManager defaultManager] isWritableFileAtPath:userPreferredDownloadFolder]) {
	NSString *originalFolder = userPreferredDownloadFolder;

	userPreferredDownloadFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];

	if (![[NSFileManager defaultManager] isWritableFileAtPath:userPreferredDownloadFolder]) {
		userPreferredDownloadFolder = NSHomeDirectory();
	}

	NSLog(@"Could not obtain write access for %@; defaulting to %@", originalFolder, userPreferredDownloadFolder);
}

return userPreferredDownloadFolder;
}

/*!
 * @brief Set the location Adium should use for saving files
 *
 * @param A path to an existing folder
 */
- (void)setUserPreferredDownloadFolder:(NSString *)path
{
	[self setPreference:[path stringByAbbreviatingWithTildeInPath]
				 forKey:@"UserPreferredDownloadFolder"
				  group:PREF_GROUP_GENERAL];
}

#pragma mark KVC

static void parseKeypath(NSString *keyPath, NSString **outGroup, NSString **outKeyPath, NSString **outInternalObjectID)
{
	NSRange prefixRange = [keyPath rangeOfString:@"Group:" options:NSLiteralSearch | NSAnchoredSearch];
	NSString *groupWithKeyPath = keyPath;
	NSString *group = nil, *finalKeyPath = nil;
	NSString *internalObjectID = nil;

	if (prefixRange.location == 0) {
		// Allow a Group: prefix, stripping it out if present.
		groupWithKeyPath = [keyPath substringFromIndex:prefixRange.length];
	} else {
		prefixRange = [keyPath rangeOfString:@"ByObject:" options:(NSLiteralSearch | NSAnchoredSearch)];
		if (prefixRange.location == 0) {
			keyPath = [keyPath substringFromIndex:prefixRange.length];

			NSRange nextPeriod = [keyPath rangeOfString:@"."
												options:NSLiteralSearch
												  range:NSMakeRange(0, [keyPath length])];
			internalObjectID = [keyPath substringToIndex:nextPeriod.location];
			groupWithKeyPath = [keyPath substringFromIndex:nextPeriod.location + 1];
		}
	}

	// We need the key to do AIPC change notifications.
	NSInteger periodIdx = [groupWithKeyPath rangeOfString:@"." options:NSLiteralSearch].location;
	if (periodIdx == NSNotFound) {
		group = groupWithKeyPath;
	} else {
		group = [groupWithKeyPath substringToIndex:periodIdx];
		finalKeyPath = [groupWithKeyPath substringFromIndex:periodIdx + 1];
	}

	if (outGroup)
		*outGroup = group;
	if (outKeyPath)
		*outKeyPath = finalKeyPath;
	if (outInternalObjectID)
		*outInternalObjectID = internalObjectID;
}

+ (BOOL)accessInstanceVariablesDirectly
{
	return NO;
}

- (void)addObserver:(NSObject *)anObserver
		 forKeyPath:(NSString *)keyPath
			options:(NSKeyValueObservingOptions)options
			context:(void *)context
{
	NSUInteger periodIdx = [keyPath rangeOfString:@"." options:NSLiteralSearch].location;
	if (periodIdx == NSNotFound) {
		[super addObserver:anObserver forKeyPath:keyPath options:options context:context];

	} else {
		NSString *group, *newKeyPath, *internalObjectID;
		parseKeypath(keyPath, &group, &newKeyPath, &internalObjectID);

		AIPreferenceContainer *prefContainer = [self
			preferenceContainerForGroup:group
								 object:(internalObjectID
											 ? [adium.contactController existingListObjectWithUniqueID:internalObjectID]
											 : nil)];
		[prefContainer addObserver:anObserver forKeyPath:newKeyPath options:options context:context];
	}
}

- (void)addObserver:(NSObject *)anObserver
		 forKeyPath:(NSString *)keyPath
		   ofObject:(AIListObject *)listObject
			options:(NSKeyValueObservingOptions)options
			context:(void *)context
{
	NSString *group, *newKeyPath, *internalObjectID;
	parseKeypath(keyPath, &group, &newKeyPath, &internalObjectID);

	AIPreferenceContainer *prefContainer = [self preferenceContainerForGroup:group object:listObject];
	[prefContainer addObserver:anObserver forKeyPath:newKeyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)anObserver forKeyPath:(NSString *)keyPath
{
	NSUInteger periodIdx = [keyPath rangeOfString:@"." options:NSLiteralSearch].location;
	if (periodIdx == NSNotFound) {
		[super removeObserver:anObserver forKeyPath:keyPath];

	} else {
		NSString *group, *newKeyPath, *internalObjectID;
		parseKeypath(keyPath, &group, &newKeyPath, &internalObjectID);

		AIPreferenceContainer *prefContainer = [self
			preferenceContainerForGroup:group
								 object:(internalObjectID
											 ? [adium.contactController existingListObjectWithUniqueID:internalObjectID]
											 : nil)];
		[prefContainer removeObserver:anObserver forKeyPath:newKeyPath];
	}
}

- (id)valueForKey:(NSString *)key
{
	return [self preferenceContainerForGroup:key object:nil];
}

- (id)valueForKeyPath:(NSString *)keyPath
{
	NSUInteger periodIdx = [keyPath rangeOfString:@"." options:NSLiteralSearch].location;
	if (periodIdx == NSNotFound) {
		return [self valueForKey:keyPath];

	} else {
		NSString *group, *newKeyPath, *internalObjectID;
		parseKeypath(keyPath, &group, &newKeyPath, &internalObjectID);

		return [[self
			preferenceContainerForGroup:group
								 object:(internalObjectID
											 ? [adium.contactController existingListObjectWithUniqueID:internalObjectID]
											 : nil)] valueForKeyPath:newKeyPath];
	}
}

/*!
 * @brief Set a dictionary of preferences for a group
 *
 * Note that while setPreferences:inGroup: adds the passed dictionary to the current one, this method replaces the
 * dictionary entirely
 *
 * @param value An NSDictionary which reprsents an entire group of preferences (without defaults)
 * @param key The group name
 */
- (void)setValue:(id)value forKey:(NSString *)key
{
	NSString *group = nil;
	NSString *internalObjectID = nil;

	parseKeypath(key, &group, NULL, &internalObjectID);

	[[self preferenceContainerForGroup:group
								object:(internalObjectID
											? [adium.contactController existingListObjectWithUniqueID:internalObjectID]
											: nil)] setPreferences:value];
}

/*
 * Key paths:
 *		No prefix: Group
 *		"Group:": Group
 *		"ByObject" (futar): by-object (objectXyz instead of xyz ivars)
 *
 * For example, General.MyKey would refer to the MyKey value of the General group, as would Group:General.MyKey
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	NSUInteger periodIdx = [keyPath rangeOfString:@"." options:NSLiteralSearch].location;
	if (periodIdx == NSNotFound) {
		NSString *key = [keyPath substringToIndex:periodIdx];

		[self setValue:value forKey:key];
	} else {
		NSString *group, *newKeyPath, *internalObjectID;
		parseKeypath(keyPath, &group, &newKeyPath, &internalObjectID);

		// Change the value.
		AIPreferenceContainer *prefContainer = [self
			preferenceContainerForGroup:group
								 object:(internalObjectID
											 ? [adium.contactController existingListObjectWithUniqueID:internalObjectID]
											 : nil)];
		[prefContainer setValue:value forKeyPath:newKeyPath];
	}
}

@end
