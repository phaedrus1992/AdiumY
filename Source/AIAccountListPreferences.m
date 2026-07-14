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

#import "AIAccountListPreferences.h"
#import "AIEditAccountWindowController.h"
#import "AIStatusController.h"
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIAutoScrollView.h>
#import <AIUtilities/AIDateFormatterAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIMutableStringAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITableViewAdditions.h>
#import <AIUtilities/AIVerticallyCenteredTextCell.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListObject.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIServiceMenu.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusIcons.h>
#import <Adium/AIStatusMenu.h>

#define MINIMUM_ROW_HEIGHT 34
#define MINIMUM_CELL_SPACING 4

#define ACCOUNT_DRAG_TYPE @"AIAccount" // ID for an account drag

#define NEW_ACCOUNT_DISPLAY_TEXT                                                                                       \
	AILocalizedString(@"<New Account>", "Placeholder displayed as the name of a new account")

@interface AIAccountListPreferences ()
- (void)configureAccountList;
- (void)accountListChanged:(NSNotification *)notification;

- (void)calculateHeightForRow:(NSInteger)row;
- (void)calculateAllHeights;

- (void)updateReconnectTime:(NSTimer *)timer;

- (void)iconPackDidChange:(NSNotification *)notification;
- (void)updateAccountsForStatus:(id)sender;
- (void)toggleOnlineForAccounts:(id)sender;
- (void)toggleEnabledForAccounts:(id)sender;
@end

/*!
 * @class AIAccountListPreferences
 * @brief Shows a list of accounts and provides for management of them
 */
@implementation AIAccountListPreferences

/*!
 * @brief Preference pane properties
 */
- (NSString *)paneIdentifier
{
	return @"Accounts";
}
- (NSString *)paneName
{
	return AILocalizedString(@"Accounts", "Accounts preferences label");
}
- (NSString *)nibName
{
	return @"AccountListPreferences";
}
- (NSImage *)paneIcon
{
	return requiredHeightDict = [[NSMutableDictionary alloc] init];

	for (accountNumber = 0; accountNumber < [accountArray count]; accountNumber++) {
		[self calculateHeightForRow:accountNumber];
	}
}

// Account List Table Delegate
// ------------------------------------------------------------------------------------------
#pragma mark Account List (Table Delegate)
/*!
 * @brief Delete the selected row
 */
- (void)tableViewDeleteSelectedRows:(NSTableView *)tableView
{
	[self deleteAccount];
}

/*!
 * @brief Number of rows in the table
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [accountArray count];
}

/*!
 * @brief Table values
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (row < 0 || row >= [accountArray count]) {
		return nil;
	}

	NSString *identifier = [tableColumn identifier];
	AIAccount *account = [accountArray objectAtIndex:row];

	if ([identifier isEqualToString:@"service"]) {
		return [[AIServiceIcons serviceIconForObject:account type:AIServiceIconLarge direction:AIIconNormal]
			imageByScalingToSize:NSMakeSize(MINIMUM_ROW_HEIGHT - 2, MINIMUM_ROW_HEIGHT - 2)
						fraction:(account.enabled ? 1.0f : 0.75f)];

	} else if ([identifier isEqualToString:@"name"]) {
		return [[account explicitFormattedUID] length] ? [account explicitFormattedUID] : NEW_ACCOUNT_DISPLAY_TEXT;

	} else if ([identifier isEqualToString:@"status"]) {
		NSString *title;

		if (account.enabled) {
			if ([account boolValueForProperty:@"isConnecting"]) {
				title = AILocalizedString(@"Connecting", nil);
			} else if ([account boolValueForProperty:@"isDisconnecting"]) {
				title = AILocalizedString(@"Disconnecting", nil);
			} else if ([account boolValueForProperty:@"isOnline"]) {
				title = AILocalizedString(@"Online", nil);
			} else if ([account valueForProperty:@"waitingToReconnect"]) {
				title = AILocalizedString(
					@"Reconnecting",
					@"Used when the account will perform an automatic reconnection after a certain period of time.");
			} else if ([account boolValueForProperty:@"isWaitingForNetwork"]) {
				title = AILocalizedString(@"Network Offline",
										  @"Used when the account will connect once the network returns.");
			} else {
				title = [adium.statusController localizedDescriptionForCoreStatusName:STATUS_NAME_OFFLINE];
			}

		} else {
			title = AILocalizedString(@"Disabled", nil);
		}

		return title;

	} else if ([identifier isEqualToString:@"statusicon"]) {

		return [AIStatusIcons statusIconForListObject:account type:AIStatusIconList direction:AIIconNormal];

	} else if ([identifier isEqualToString:@"enabled"]) {
		return nil;
	}

	return nil;
}
/*!
 * @brief Configure the height of each account for error messages if necessary
 */
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	// We should probably have this value cached.
	CGFloat necessaryHeight = MINIMUM_ROW_HEIGHT;

	NSNumber *cachedHeight = [requiredHeightDict objectForKey:[NSNumber numberWithInteger:row]];
	if (cachedHeight) {
		necessaryHeight = (CGFloat)[cachedHeight doubleValue];
	}

	return necessaryHeight;
}

/*!
 * @brief Configure cells before display
 */
- (void)tableView:(NSTableView *)tableView
	willDisplayCell:(id)cell
	 forTableColumn:(NSTableColumn *)tableColumn
				row:(NSInteger)row
{
	// Make sure this row actually exists
	if (row < 0 || row >= [accountArray count]) {
		return;
	}

	NSString *identifier = [tableColumn identifier];
	AIAccount *account = [accountArray objectAtIndex:row];

	if ([identifier isEqualToString:@"enabled"]) {
		[cell setState:(account.enabled ? NSOnState : NSOffState)];

	} else if ([identifier isEqualToString:@"name"]) {
		if ([account encrypted]) {
			[cell setImage:[NSImage imageForSSL]];
		} else {
			[cell setImage:nil];
		}

		[cell setImageTextPadding:MINIMUM_CELL_SPACING / 2.0f];

		[cell setEnabled:account.enabled];

		// Update the subString with our current status message (if it exists);
		[cell setSubString:[self statusMessageForAccount:account]];

	} else if ([identifier isEqualToString:@"service"]) {
		[cell accessibilitySetOverrideValue:[account.service longDescription]
							   forAttribute:NSAccessibilityTitleAttribute];
		[cell accessibilitySetOverrideValue:@" " forAttribute:NSAccessibilityRoleDescriptionAttribute];

	} else if ([identifier isEqualToString:@"status"]) {
		if (account.enabled && ![account boolValueForProperty:@"isConnecting"] &&
			[account valueForProperty:@"waitingToReconnect"]) {
			NSString *format = [NSDateFormatter
				stringForTimeInterval:[[account valueForProperty:@"waitingToReconnect"] timeIntervalSinceNow]
					   showingSeconds:YES
						  abbreviated:YES
						 approximated:NO];

			[cell setSubString:[NSString
								   stringWithFormat:AILocalizedString(@"...in %@",
																	  @"The amount of time until a reconnect occurs. "
																	  @"%@ is the formatted time remaining."),
													format]];
		} else {
			[cell setSubString:nil];
		}

		[cell setEnabled:([account boolValueForProperty:@"isConnecting"] ||
						  [account valueForProperty:@"waitingToReconnect"] ||
						  [account boolValueForProperty:@"isDisconnecting"] ||
						  [account boolValueForProperty:@"isOnline"])];

	} else if ([identifier isEqualToString:@"statusicon"]) {
		[cell accessibilitySetOverrideValue:@" " forAttribute:NSAccessibilityTitleAttribute];
		[cell accessibilitySetOverrideValue:@" " forAttribute:NSAccessibilityRoleDescriptionAttribute];

	} else if ([identifier isEqualToString:@"blank1"] || [identifier isEqualToString:@"blank2"]) {
		[cell accessibilitySetOverrideValue:@" " forAttribute:NSAccessibilityTitleAttribute];
		[cell accessibilitySetOverrideValue:@" " forAttribute:NSAccessibilityRoleDescriptionAttribute];
	}
}

/*!
 * @brief Handle a clicked active/inactive checkbox
 *
 * Checking the box both takes the account online and sets it to autoconnect. Unchecking it does the opposite.
 */
- (void)tableView:(NSTableView *)tableView
	setObjectValue:(id)object
	forTableColumn:(NSTableColumn *)tableColumn
			   row:(NSInteger)row
{
	if (row >= 0 && row < [accountArray count] && [[tableColumn identifier] isEqualToString:@"enabled"]) {
		[[accountArray objectAtIndex:row] setEnabled:[(NSNumber *)object boolValue]];
	}
}

/*!
 * @brief Drag start
 */
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard *)pboard
{
	tempDragAccounts = [accountArray objectsAtIndexes:rows];

	[pboard declareTypes:[NSArray arrayWithObject:ACCOUNT_DRAG_TYPE] owner:self];
	[pboard setString:@"Account" forType:ACCOUNT_DRAG_TYPE];

	return YES;
}

/*!
 * @brief Drag validate
 */
- (NSDragOperation)tableView:(NSTableView *)tv
				validateDrop:(id<NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)op
{
	if (op == NSTableViewDropAbove && row != -1) {
		return NSDragOperationPrivate;
	} else {
		return NSDragOperationNone;
	}
}

/*!
 * @brief Drag complete
 */
- (BOOL)tableView:(NSTableView *)tv
	   acceptDrop:(id<NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)op
{
	NSString *avaliableType =
		[[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:ACCOUNT_DRAG_TYPE]];

	if ([avaliableType isEqualToString:@"AIAccount"]) {
		NSEnumerator *enumerator;

		// Indexes are shifting as we're doing this, so we have to iterate in the right order
		// If we're moving accounts to an earlier point in the list, we've got to insert backwards
		if ([accountArray indexOfObject:[tempDragAccounts objectAtIndex:0]] >= row)
			enumerator = [tempDragAccounts reverseObjectEnumerator];
		else // If we're inserting into a later part of the list, we've got to insert forwards
			enumerator = [tempDragAccounts objectEnumerator];

		[tableView_accountList deselectAll:nil];

		for (AIAccount *account in enumerator) {
			[adium.accountController moveAccount:account toIndex:row];
		}

		// Re-select our now-moved accounts
		[tableView_accountList
				selectRowIndexes:[NSIndexSet
									 indexSetWithIndexesInRange:NSMakeRange(
																	[accountArray indexOfObject:[tempDragAccounts
																									objectAtIndex:0]],
																	[tempDragAccounts count])]
			byExtendingSelection:NO];

		return YES;
	} else {
		return NO;
	}
}

/*!
 * @brief Selection change
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self updateControlAvailability];
}

- (NSMenu *)tableView:(NSTableView *)inTableView menuForEvent:(NSEvent *)theEvent
{
	NSIndexSet *selectedIndexes = [inTableView selectedRowIndexes];
	NSInteger mouseRow = [inTableView rowAtPoint:[inTableView convertPoint:[theEvent locationInWindow] toView:nil]];

	// Multiple rows selected where the right-clicked row is in the selection
	if ([selectedIndexes count] > 1 && [selectedIndexes containsIndex:mouseRow]) {
		// Display a multi-selection menu
		return [self menuForRowIndexes:selectedIndexes];
	} else {
		// Otherwise, select our new row and provide a menu for it.
		[inTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:mouseRow] byExtendingSelection:NO];

		// Return our delegate's menu for this row.
		return [self menuForRow:mouseRow];
	}
}

@end
