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

#import "ESAwayStatusWindowController.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AITableViewAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AIStatusIcons.h>

#define AWAY_STATUS_WINDOW_NIB @"AwayStatusWindow"
#define KEY_AWAY_STATUS_WINDOW_FRAME @"Away Status Window Frame"

@interface ESAwayStatusWindowController ()
- (void)localizeButtons;
- (void)configureStatusWindow;
- (NSAttributedString *)attributedStatusTitleForStatus:(AIStatus *)statusState withIcon:(NSImage *)statusIcon;
- (NSArray *)awayAccounts;
- (void)setupMultistatusTable;
- (void)statusIconSetChanged:(NSNotification *)inNotification;
@end

/*!
 * @class ESAwayStatusWindowController
 * @brief Window controller for the status window which optionally shows when one or more accounts are away or invisible
 */
@implementation ESAwayStatusWindowController

static ESAwayStatusWindowController *sharedInstance = nil;
static BOOL alwaysOnTop = NO;
static BOOL hideInBackground = NO;

/*!
 * @brief Update the visibility of the status window
 *
 * Opens or closes the window if necessary.
 *
 * If shouldBeVisibile is YES and the window is already visible, updates its contents to reflect the current status.
 * If shouldBeVisible is NO and the window is already not visibile, no action is taken.
 */
+ (void)updateStatusWindowWithVisibility:(BOOL)shouldBeVisible
{
	if (shouldBeVisible) {
		if (sharedInstance) {
			// Update the window's configuration
		}

		/*!
		 * @brief Perform initial setup for the multistatus table
		 */
		-(void)setupMultistatusTable
		{
			[[tableView_multiStatus tableColumnWithIdentifier:@"status"] setDataCell:[[AIImageTextCell alloc] init]];
		}

#pragma mark Multiservice table view datasource
		/*!
		 * @brief Number of rows in the table
		 */
		-(NSInteger)numberOfRowsInTableView : (NSTableView *)tableView
		{
			return [_awayAccounts count];
		}

		/*!
		 * @brief Table values
		 *
		 * Object value is the account's formatted UID
		 */
		-(id)tableView : (NSTableView *)tableView objectValueForTableColumn : (NSTableColumn *)tableColumn row
			: (NSInteger)row
		{
			AIAccount *account = [_awayAccounts objectAtIndex:row];

			return account.formattedUID;
		}

		/*!
		 * @brief Will display a cell
		 *
		 * Set the image (status icon) and substring (status title) before display.  Cell is an AIImageTextCell.
		 */
		-(void)tableView : (NSTableView *)tableView willDisplayCell : (id)cell forTableColumn
			: (NSTableColumn *)tableColumn row : (NSInteger)row
		{
			AIAccount *account = [_awayAccounts objectAtIndex:row];

			[cell setImage:[AIStatusIcons statusIconForListObject:account type:AIStatusIconTab direction:AIIconNormal]];
			[cell setSubString:[account.statusState title]];
		}

		-(void)localizeButtons
		{
			[button_return setLocalizedString:AILocalizedStringFromTableInBundle(
												  @"Return", @"Buttons", [NSBundle bundleForClass:[self class]],
												  "Button to return from away in the away status window")];
		}

		-(void)statusIconSetChanged : (NSNotification *)inNotification
		{
			[self configureStatusWindow];
		}

	@end
