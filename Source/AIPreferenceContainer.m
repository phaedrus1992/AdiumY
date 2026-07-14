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

#import "AIPreferenceContainer.h"
#import "AIPreferenceController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIListObject.h>
#import <Adium/AILoginControllerProtocol.h>

@interface AIPreferenceContainer ()
- (id)initForGroup:(NSString *)inGroup object:(AIListObject *)inObject;
- (void)save;
@property(readonly, nonatomic) NSMutableDictionary *prefs;
- (void)loadGlobalPrefs;

// Lazily sets up our pref dict if needed
- (void)setPrefValue:(id)val forKey:(id)key;
@end

#define SAVE_OBJECT_PREFS_DELAY 10.0

/* XXX Remove me */
#ifdef DEBUG_BUILD
#define PREFERENCE_CONTAINER_DEBUG
#endif

static NSMutableDictionary *objectPrefs = nil;
static NSTimer *timer_savingOfObjectCache = nil;

static NSMutableDictionary *accountPrefs = nil;
static NSTimer *timer_savingOfAccountCache = nil;

/*!
 * @brief Preference Container
 *
 * A single AIPreferenceContainer instance provides read/write access preferences to a specific preference group, either
 * for the global preferences or for a specific object.
 *
 * All contacts share a single plist on-disk, loaded into a single mutable dictionary in-memory, objectPrefs.
 * All accounts share a single plist on-disk, loaded into a single mutable dictionary in-memory, accountPrefs.
 * These global dictionaries provide per-object preference dictionaries, keyed by the object's internalObjectID.
 *
 * Individual instances of AIPreferenceContainer make use of this shared store.  Saving of changes is batched for all
 * changes made during a SAVE_OBJECT_PREFS_DELAY interval across all instances of AIPreferenceContainer for a given
 * global dictionary. Because creating the data representation of a large dictionary and writing it out can be
 * time-consuming (certainly less than a second, but still long enough to cause a perceptible delay for a user actively
 * typing or interacting with Adium), saving is performed on a thread.
 */
@implementation AIPreferenceContainer

+ (AIPreferenceContainer *)preferenceContainerForGroup:(NSString *)inGroup object:(AIListObject *)inObject
{
	return group = inGroup;
}
}

#pragma mark Debug
- (NSString *)description
{
	return [NSString
		stringWithFormat:@"<%@ %p: Group %@, object %@>", NSStringFromClass([self class]), self, group, object];
}
@end
