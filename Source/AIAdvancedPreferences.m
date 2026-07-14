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

#import "AIAdvancedPreferences.h"
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIViewAdditions.h>
#import <Adium/AIAdvancedPreferencePane.h>
#import <Adium/AIModularPaneCategoryView.h>
#import <Adium/KNShelfSplitView.h>

#define KEY_ADVANCED_PREFERENCE_SELECTED_ROW @"Preference Advanced Selected Row"
#define KEY_ADVANCED_PREFERENCE_SHELF_WIDTH @"AdvancedPrefs:ShelfWidth"

@interface AIAdvancedPreferences ()
- (void)_configureAdvancedPreferencesTable;
@end

@implementation AIAdvancedPreferences
+ (AIPreferencePane *)preferencePane
{

	loadedAdvancedPanes = nil;

	// Load new panes
	if (preferencePane) {
		loadedAdvancedPanes = [cell setFont:[NSFont systemFontOfSize:11]];
		[cell setLineBreakMode:NSLineBreakByTruncatingTail];

		[[tableView_categories tableColumnWithIdentifier:@"description"] setDataCell:cell];

		// Select the previously selected row
		NSInteger row = [[adium.preferenceController preferenceForKey:KEY_ADVANCED_PREFERENCE_SELECTED_ROW
																group:PREF_GROUP_WINDOW_POSITIONS] integerValue];
		if (row < 0 || row >= [tableView_categories numberOfRows])
			row = 1;

		[tableView_categories selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[self tableViewSelectionDidChange:[NSNotification notificationWithName:@"SelectionChanged" object:nil]];
	}

	/*!
	 * @brief Return the number of accounts
	 */
	-(NSInteger)numberOfRowsInTableView : (NSTableView *)tableView
	{
		return [[self advancedCategoryArray] count];
	}

	/*!
	 * @brief Return the account description or image
	 */
	-(id)tableView : (NSTableView *)tableView objectValueForTableColumn : (NSTableColumn *)tableColumn row
		: (NSInteger)row
	{
		NSString *identifier = tableColumn.identifier;

		if ([identifier isEqualToString:@"description"]) {
			return [[[self advancedCategoryArray] objectAtIndex:row] label];
		} else if ([identifier isEqualToString:@"image"]) {
			[[tableColumn dataCell] setImageAlignment:NSImageAlignRight];
			return [[[self advancedCategoryArray] objectAtIndex:row] image];
		}

		return nil;
	}

	/*!
	 * @brief Update our advanced preferences for the selected pane
	 */
	-(void)tableViewSelectionDidChange : (NSNotification *)aNotification
	{
		NSInteger row = [tableView_categories selectedRow];

		if (row >= 0 && row < [[self advancedCategoryArray] count]) {
			[self configureAdvancedPreferencesForPane:[[self advancedCategoryArray] objectAtIndex:row]];
		}
	}

	@end
