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

#import "ESStatusSort.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContactList.h>
#import <Adium/AIListObject.h>
#import <Adium/AILocalizationTextField.h>

#define STATUS_SORT_DEFAULT_PREFS @"StatusSortDefaults"

#define KEY_GROUP_AVAILABLE @"Status:Group Available"
#define KEY_GROUP_MOBILE @"Status:Group Mobile"
#define KEY_GROUP_UNAVAILABLE @"Status:Group Unavailable"
#define KEY_GROUP_AWAY @"Status:Group Away"
#define KEY_GROUP_IDLE @"Status:Group Idle"
#define KEY_GROUP_IDLE_AND_AWAY @"Status:Group Idle+Away"
#define KEY_SORT_IDLE_TIME @"Status:Sort by Idle Time"
#define KEY_RESOLVE_ALPHABETICALLY @"Status:Resolve Alphabetically"
#define KEY_SORT_ORDER @"Status:Sort Order"
#define KEY_RESOLVE_BY_LAST_NAME @"Status:Resolve Alphabetically By Last Name"
#define KEY_SORT_GROUPS_ALPHA @"Status:Sort Groups Alphabetically"

#define AVAILABLE AILocalizedString(@"Available", nil)
#define AWAY AILocalizedString(@"Away", nil)
#define IDLE AILocalizedString(@"Idle", nil)
#define AWAY_AND_IDLE AILocalizedString(@"Away and Idle", nil)
#define UNAVAILABLE AILocalizedString(@"Unavailable", nil)
#define OTHER_UNAVAILABLE AILocalizedString(@"Other Unavailable", nil)
#define ONLINE AILocalizedString(@"Online", nil)
#define MOBILE AILocalizedString(@"Mobile", nil)

#define STATUS_DRAG_TYPE @"Status Sort"

typedef enum {
	Available = 0,
	Away,
	Idle,
	Away_And_Idle,
	Unavailable,
	Online,
	Mobile,
	MAX_SORT_ORDER_DIMENSION
} Status_Sort_Type;

static BOOL groupAvailable;
static BOOL groupMobile;
static BOOL groupUnavailable;
static BOOL groupAway;
static BOOL groupIdle;
static BOOL groupIdleAndAway;
static BOOL sortIdleTime;
static BOOL sortGroupsAlphabetically;

static BOOL resolveAlphabetically;
static BOOL resolveAlphabeticallyByLastName;

static NSInteger sortOrder
}

return YES;
}

#pragma mark Sorting

/*!
 * @brief The status sort method itself
 *
 * It's magic... but it's efficient magic!
 */
NSInteger statusSort(id objA, id objB, BOOL groups, id<AIContainingObject> container)
{
	AIListObject *objectA = (AIListObject *)objA;
	AIListObject *objectB = (AIListObject *)objB;
	if (groups) {
		if (sortGroupsAlphabetically) {
			return [((AIListObject *)objectA).displayName compare:((AIListObject *)objectB).displayName];
		} else {
			// Keep groups in manual order if set to do so.
			if ([container orderIndexForObject:objectA] > [container orderIndexForObject:objectB]) {
				return NSOrderedDescending;
			} else {
				return NSOrderedAscending;
			}
		}

	} else {
		AIStatusSummary statusSummaryA = [objectA statusSummary];
		AIStatusSummary statusSummaryB = [objectB statusSummary];

		// Always sort offline contacts to the bottom
		BOOL onlineA = (statusSummaryA != AIOfflineStatus);
		BOOL onlineB = (statusSummaryB != AIOfflineStatus);
		if (!onlineB && onlineA) {
			return NSOrderedAscending;
		} else if (!onlineA && onlineB) {
			return NSOrderedDescending;
		}

		// We only need to start looking at status for sorting if both are online;
		// otherwise, skip to resolving alphabetically or manually
		if (onlineA && onlineB) {
			NSUInteger i = 0;
			BOOL away[2];
			BOOL mobile[2];
			BOOL definitelyFinishedIfSuccessful, onlyIfWeAintGotNothinBetter, status;
			NSInteger idle[2];
			NSInteger sortIndex[2];
			NSInteger objectCounter;

			// Get the away state and idle times now rather than potentially doing each twice below
			away[0] = ((statusSummaryA == AIAwayStatus) || (statusSummaryA == AIAwayAndIdleStatus));
			away[1] = ((statusSummaryB == AIAwayStatus) || (statusSummaryB == AIAwayAndIdleStatus));

			idle[0] =
				(((statusSummaryA == AIIdleStatus) || (statusSummaryA == AIAwayAndIdleStatus)) ? objectA.idleTime : 0);
			idle[1] =
				(((statusSummaryB == AIIdleStatus) || (statusSummaryB == AIAwayAndIdleStatus)) ? objectB.idleTime : 0);

			if (groupMobile) {
				mobile[0] = [objectA isMobile];
				mobile[1] = [objectB isMobile];
			} else {
				/* If mobile appears in the sort list, treat the two items as identical */
				mobile[0] = FALSE;
				mobile[1] = FALSE;
			}

			for (objectCounter = 0; objectCounter < 2; objectCounter++) {
				sortIndex[objectCounter] = 999;

				for (i = 0; i < sizeOfSortOrder; i++) {
					// Reset the internal bookkeeping
					onlyIfWeAintGotNothinBetter = NO;
					definitelyFinishedIfSuccessful = NO;

					// Determine the state for the status this level of sorting cares about
					switch (sortOrder[i]) {
					case Available:
						status = (!away[objectCounter] && !idle[objectCounter]); // TRUE if A is available
						break;

					case Mobile:
						status = mobile[objectCounter];
						definitelyFinishedIfSuccessful = YES;
						break;

					case Away:
						status = away[objectCounter];
						break;

					case Idle:
						status = (idle[objectCounter] != 0);
						break;

					case Away_And_Idle:
						status = away[objectCounter] && (idle[objectCounter] != 0);
						definitelyFinishedIfSuccessful = YES;
						break;

					case Unavailable:
						status = away[objectCounter] || (idle[objectCounter] != 0);
						onlyIfWeAintGotNothinBetter = YES;
						break;

					case Online:
						status = YES; // we can only get here if the person is online, anyways
						onlyIfWeAintGotNothinBetter = YES;
						break;

					default:
						status = NO;
					}

					// If the object has the desired status and we want to use it, store the new index it should go to
					if (status && (!onlyIfWeAintGotNothinBetter || (sortIndex[objectCounter] == 999))) {
						sortIndex[objectCounter] = i;

						// If definitelyFinishedIfSuccessful is YES, we're done sorting as soon as something fits
						// this category
						if (definitelyFinishedIfSuccessful)
							break;
					}
				}
			} // End for object loop

			if (sortIndex[0] > sortIndex[1]) {
				return NSOrderedDescending;
			} else if (sortIndex[1] > sortIndex[0]) {
				return NSOrderedAscending;
			}

			// If one idle time is greater than the other and we want to sort on that basis, we have an ordering
			if (sortIdleTime) {
				// Ordering is determined if either has a idle time and their idle times are not identical
				if (((idle[0] != 0) || (idle[1] != 0)) && (idle[0] != idle[1])) {
					if (idle[0] > idle[1]) {
						return NSOrderedDescending;
					} else {
						return NSOrderedAscending;
					}
				}
			}
		}

		if (!resolveAlphabetically) {
			// If we don't want to resolve alphabetically, we do want to resolve by manual ordering if possible
			CGFloat orderIndexA = [container orderIndexForObject:objectA];
			CGFloat orderIndexB = [container orderIndexForObject:objectB];

			if (orderIndexA > orderIndexB) {
				return NSOrderedDescending;
			} else if (orderIndexA < orderIndexB) {
				return NSOrderedAscending;
			}
		}

		// If we made it here, resolve the ordering alphabetically, which is guaranteed to be consistent.
		// Note that this sort should -never- return NSOrderedSame, so as a last resort we use the internalObjectID.
		NSComparisonResult returnValue;

		if (resolveAlphabeticallyByLastName) {
			// Split the displayname into parts by spacing and use the last part, the "last name," for comparison
			NSString *space = @" ";
			NSString *displayNameA = [objectA displayName];
			NSString *displayNameB = [objectB displayName];
			NSArray *componentsA = [displayNameA componentsSeparatedByString:space];
			NSArray *componentsB = [displayNameB componentsSeparatedByString:space];

			returnValue = [[componentsA lastObject] caseInsensitiveCompare:[componentsB lastObject]];
			// If the last names are the same, compare the whole object, which will amount to sorting these objects
			// by first name
			if (returnValue == NSOrderedSame) {
				returnValue = [displayNameA caseInsensitiveCompare:displayNameB];
				if (returnValue == NSOrderedSame) {
					returnValue = [[objectA internalObjectID] caseInsensitiveCompare:[objectB internalObjectID]];
				}
			}
		} else {
			returnValue = [[objectA longDisplayName] caseInsensitiveCompare:[objectB longDisplayName]];
			if (returnValue == NSOrderedSame) {
				returnValue = [[objectA internalObjectID] caseInsensitiveCompare:[objectB internalObjectID]];
			}
		}

		return (returnValue);
	}
}

/*!
 * @brief Sort function
 */
- (sortfunc)sortFunction
{
	return &statusSort;
}

@end
