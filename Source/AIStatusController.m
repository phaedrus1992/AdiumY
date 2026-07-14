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

#import "AIStatusController.h"

#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AISoundControllerProtocol.h>

#import "AdiumIdleManager.h"
#import <Adium/AIContactControllerProtocol.h>

#import "AIStatusGroup.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIEventAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIObjectAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIService.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusIcons.h>

// State menu
#define STATUS_TITLE_OFFLINE AILocalizedStringFromTable(@"Offline", @"Statuses", "Name of a status")

#define BUILT_IN_STATE_ARRAY @"BuiltInStatusStates"

@interface AIStatusController ()
- (NSArray *)builtInStateArray;

- (void)_upgradeSavedAwaysToSavedStates;

- (NSArray *)_menuItemsForStatusesOfType:(AIStatusType)type
				  forServiceCodeUniqueID:(NSString *)inServiceCodeUniqueID
							  withTarget:(id)target;
- (void)_addMenuItemsForStatusOfType:(AIStatusType)type
						  withTarget:(id)target
							 fromSet:(NSSet *)sourceArray
							 toArray:(NSMutableArray *)menuItems
				  alreadyAddedTitles:(NSMutableSet *)alreadyAddedTitles;
- (void)buildBuiltInStatusTypes;
- (void)notifyOfChangedStatusArray;
@end

/*!
 * @class AIStatusController
 * @brief Core status & state methods
 *
 * This class provides a foundation for Adium's status and status state systems.
 */
@implementation AIStatusController

static NSMutableSet *temporaryStateArray = nil;

/*!
 * Init the status controller
 */
- (id)init
{
	if ((self = 
	_flatStatusSet = nil;

	if (!statusMenuRebuildDelays) {
		if (!lastStatusStates)
			lastStatusStates = [NSMutableDictionary dictionary];

		[lastStatusStates setObject:[NSKeyedArchiver archivedDataWithRootObject:statusState]
							 forKey:[[NSNumber numberWithInteger:statusState.statusType] stringValue]];

		[adium.preferenceController setPreference:lastStatusStates
										   forKey:@"LastStatusStates"
											group:PREF_GROUP_STATUS_PREFERENCES];
}
// Status state menu support
// ---------------------------------------------------------------------------------------------------
#pragma mark Status state menu support
/*!
 * @brief Apply a custom state
 *
 * Invoked when the custom state window is closed by the user clicking OK.  In response this method sets the custom
 * state as the active state.
 */
- (void)customStatusState:(AIStatus *)originalState changedTo:(AIStatus *)newState forAccount:(AIAccount *)account
{
		BOOL shouldRebuild = NO;

		if ([newState mutabilityType] != AITemporaryEditableStatusState) {
			[adium.statusController addStatusState:newState];
		}

		if (account) {
			shouldRebuild = [self removeIfNecessaryTemporaryStatusState:originalState];

			// Now set the newState for the account
			[account setStatusState:newState];

			// Enable the account if it isn't currently enabled
			if (!account.enabled) {
				[account setEnabled:YES];
			}

			// Add to our temporary status array if it's not in our state array
			if (shouldRebuild || (![[self flatStatusSet] containsObject:newState])) {
				[temporaryStateArray addObject:newState];

				[self notifyOfChangedStatusArray];
			}

		} else {
			// Set the state for all accounts.  This will clear out the temporaryStatusArray as necessary and update its
			// contents.
			[self setActiveStatusState:newState];
		}

		[self saveStatusAsLastUsed:newState];
}

#pragma mark Upgrade code
/*!
 * @brief Temporary upgrade code for 0.7x -> 0.8
 *
 * Versions 0.7x and prior stored their away messages in a different format.  This code allows a seamless
 * transition from 0.7x to 0.8.  We can easily recognize the old format because the away messages are of
 * type "Away" instead of type "State", which is used for all 0.8 and later saved states.
 * Since we are changing the array as we scan it, an enumerator will not work here.
 */
#define OLD_KEY_SAVED_AWAYS @"Saved Away Messages"
#define OLD_GROUP_AWAY_MESSAGES @"Away Messages"
#define OLD_STATE_SAVED_AWAY @"Away"
#define OLD_STATE_AWAY @"Message"
#define OLD_STATE_AUTO_REPLY @"Autoresponse"
#define OLD_STATE_TITLE @"Title"
- (void)_upgradeSavedAwaysToSavedStates
{
		NSArray *savedAways = [adium.preferenceController preferenceForKey:OLD_KEY_SAVED_AWAYS
																	 group:OLD_GROUP_AWAY_MESSAGES];

		if (savedAways) {
			NSDictionary *state;

			AILog(@"*** Upgrading Adium 0.7x saved aways: %@", savedAways);

			[self setDelayStatusMenuRebuilding:YES];

			// Update all the away messages to states.
			for (state in savedAways) {
				if ([[state objectForKey:@"Type"] isEqualToString:OLD_STATE_SAVED_AWAY]) {
					AIStatus *statusState;

					// Extract the away message information from this old record
					NSData *statusMessageData = [state objectForKey:OLD_STATE_AWAY];
					NSData *autoReplyMessageData = [state objectForKey:OLD_STATE_AUTO_REPLY];
					NSString *title = [state objectForKey:OLD_STATE_TITLE];

					// Create an AIStatus from this information
					statusState = [AIStatus status];

					// General category: It's an away type
					[statusState setStatusType:AIAwayStatusType];

					// Specific state: It's the generic away. Funny how that works out.
					[statusState setStatusName:STATUS_NAME_AWAY];

					// Set the status message (which is just the away message).
					[statusState setStatusMessage:[NSAttributedString stringWithData:statusMessageData]];

					// It has an auto reply.
					[statusState setHasAutoReply:YES];

					if (autoReplyMessageData) {
						// Use the custom auto reply if it was set.
						[statusState setAutoReply:[NSAttributedString stringWithData:autoReplyMessageData]];
					} else {
						// If no autoReplyMesssage, use the status message.
						[statusState setAutoReplyIsStatusMessage:YES];
					}

					if (title)
						[statusState setTitle:title];

					// Add the updated state to our state array.
					[self addStatusState:statusState];
				}
			}

			AILog(@"*** Finished upgrading old saved statuses");

			// Save these changes and delete the old aways so we don't need to do this again.
			[self setDelayStatusMenuRebuilding:NO];

			[adium.preferenceController setPreference:nil forKey:OLD_KEY_SAVED_AWAYS group:OLD_GROUP_AWAY_MESSAGES];
		}
}

@end
