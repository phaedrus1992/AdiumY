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

#import "AIXtrasManager.h"
#import "AIXtraInfo.h"
#import "AIXtraPreviewController.h"
#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIFileManagerAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIToolbarUtilities.h>
#import <Adium/AIDockControllerProtocol.h>
#import <Adium/AIPathUtilities.h>
#import <Adium/KNShelfSplitView.h>

#define ADIUM_XTRAS_PAGE                                                                                               \
	AILocalizedString(@"https://github.com/phaedrus1992/adiumy",                                                       \
					  "Adium xtras page. Localized only if a translated version exists.")
#define DELETE AILocalizedStringFromTable(@"Delete", @"Buttons", nil)
#define GET_MORE_XTRAS                                                                                                 \
	AILocalizedStringFromTable(                                                                                        \
		@"Get More Xtras", @"Buttons",                                                                                 \
		"Button in the Xtras Manager to go to github.com/phaedrus1992/adiumy to get more adiumyextras")

#define MINIMUM_SOURCE_LIST_WIDTH 40

@interface AIXtrasManager ()
- (void)installToolbar;
- (void)updateForSelectedCategory;
- (void)xtrasChanged:(NSNotification *)not;
@end

@implementation AIXtrasManager

static AIXtrasManager *manager;

+ (AIXtrasManager *)sharedManager
{
	return manager;
}

- (void)installPlugin
{
	manager = self;
}

- (void)windowDidLoad
{}

return xtras;
}

- (void)updateForSelectedCategory
{

	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setSizeMode:NSToolbarSizeModeRegular];
	[toolbar setVisible:YES];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	toolbarItems = [[NSMutableDictionary alloc] init];

	// Delete Logs
	[AIToolbarUtilities addToolbarItemToDictionary:toolbarItems
									withIdentifier:@"delete"
											 label:DELETE
									  paletteLabel:DELETE
										   toolTip:AILocalizedString(@"Delete the selection", nil)
											target:self
								   settingSelector:@selector(setImage:)
									   itemContent:[NSImage imageNamed:@"remove" forClass:[self class]]
											action:@selector(deleteXtra:)
											  menu:nil];

	[AIToolbarUtilities addToolbarItemToDictionary:toolbarItems
									withIdentifier:@"getmoreXtras"
											 label:GET_MORE_XTRAS
									  paletteLabel:GET_MORE_XTRAS
										   toolTip:GET_MORE_XTRAS
											target:self
								   settingSelector:@selector(setImage:)
									   itemContent:[NSImage imageNamed:@"xtras_duck" forClass:[self class]]
											action:@selector(browseXtras:)
											  menu:nil];

	[[self window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
		itemForItemIdentifier:(NSString *)itemIdentifier
	willBeInsertedIntoToolbar:(BOOL)flag
{
	return [AIToolbarUtilities toolbarItemFromDictionary:toolbarItems withIdentifier:itemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"getmoreXtras", NSToolbarFlexibleSpaceItemIdentifier, @"delete", nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [[toolbarItems allKeys]
		arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier,
																NSToolbarSpaceItemIdentifier,
																NSToolbarFlexibleSpaceItemIdentifier,
																NSToolbarCustomizeToolbarItemIdentifier, nil]];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	if ([[theItem itemIdentifier] isEqualToString:@"delete"]) {
		return ([[xtraList selectedRowIndexes] count] > 0);

	} else {
		return YES;
	}
}

- (CGFloat)shelfSplitView:(KNShelfSplitView *)shelfSplitView validateWidth:(CGFloat)proposedWidth
{
	return ((proposedWidth > MINIMUM_SOURCE_LIST_WIDTH) ? proposedWidth : MINIMUM_SOURCE_LIST_WIDTH);
}

@end
