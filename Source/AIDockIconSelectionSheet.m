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

#import "AIDockIconSelectionSheet.h"
#import "AIAppearancePreferencesPlugin.h"
#import "AIDockController.h"
#import <AIUtilities/AIFileManagerAdditions.h>
#import <Adium/AIDockControllerProtocol.h>
#import <Adium/AIIconState.h>

#define PREF_GROUP_DOCK_ICON @"Dock Icon"
#define DEFAULT_DOCK_ICON_NAME @"Adiumy Green"

@interface AIDockIconSelectionSheet ()

- (void)selectIconWithName:(NSString *)selectName;
- (void)xtrasChanged:(NSNotification *)notification;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)trashConfirmSheetDidEnd:(NSWindow *)sheet
					 returnCode:(NSInteger)returnCode
					contextInfo:(NSString *)selectedIconPath;

@end

@implementation AIDockIconSelectionSheet

@synthesize imageCollectionView, okButton;
@synthesize icons, iconsData, animatedIconState, animatedIndex, animationTimer, previousIndex;

- (id)init
{
	if (self =
}

// Animate the hovered icon
- (void)animate:(NSTimer *)timer
{
	[animatedIconState nextFrame];

	[[self imageCollectionView] setImage:animatedIconState.image forItemAtIndex:animatedIndex];
}

#pragma mark - AIImageCollectionViewDelegate

- (BOOL)imageCollectionView:(AIImageCollectionView *)collectionView shouldHighlightItemAtIndex:(NSUInteger)anIndex
{
	// Stop animation
	if (anIndex == NSNotFound) {
		[self setAnimatedDockIconAtIndex:NSNotFound];
	}

	return (anIndex < [[self icons] count]);
}

- (BOOL)imageCollectionView:(AIImageCollectionView *)imageCollectionView shouldSelectItemAtIndex:(NSUInteger)anIndex
{
	// Prevent empty selection
	if (anIndex == NSNotFound) {
		if ([self previousIndex] == [[self icons] count] || [self previousIndex] == NSNotFound) {
			[self selectIconWithName:[adium.preferenceController preferenceForKey:KEY_ACTIVE_DOCK_ICON
																			group:PREF_GROUP_APPEARANCE]];
		} else {
			[[self imageCollectionView] setSelectionIndexes:[NSIndexSet indexSetWithIndex:previousIndex]];
		}
	}

	return (anIndex < [[self icons] count]);
}

- (BOOL)imageCollectionView:(AIImageCollectionView *)imageCollectionView
	shouldDeleteItemsAtIndexes:(NSIndexSet *)indexes
{
	return ([indexes firstIndex] < [[self icons] count]);
}

- (void)imageCollectionView:(AIImageCollectionView *)imageCollectionView didHighlightItemAtIndex:(NSUInteger)anIndex
{
	[self setAnimatedDockIconAtIndex:anIndex];
}

- (void)imageCollectionView:(AIImageCollectionView *)imageCollectionView didSelectItemAtIndex:(NSUInteger)anIndex
{
	NSString *iconName = [[[[[self iconsData] objectAtIndex:anIndex] objectForKey:@"Path"] lastPathComponent]
		stringByDeletingPathExtension];

	if (![[adium.preferenceController preferenceForKey:KEY_ACTIVE_DOCK_ICON
												 group:PREF_GROUP_APPEARANCE] isEqualToString:iconName]) {
		[adium.preferenceController setPreference:iconName forKey:KEY_ACTIVE_DOCK_ICON group:PREF_GROUP_APPEARANCE];

		// Set previous index
		[self setPreviousIndex:anIndex];
	}
}

#pragma mark - Deleting dock xtras

// Delete the selected dock icon
- (void)imageCollectionView:(AIImageCollectionView *)imageCollectionView didDeleteItemsAtIndexes:(NSIndexSet *)indexes
{
	NSString *selectedIconPath =
		[[iconsData objectAtIndex:[[[self imageCollectionView] selectionIndexes] firstIndex]] valueForKey:@"Path"];
	NSString *name = [[selectedIconPath lastPathComponent] stringByDeletingPathExtension];

	// We need at least one icon installed, so prevent the user from deleting the default icon
	if (![name isEqualToString:DEFAULT_DOCK_ICON_NAME]) {
		NSBeginAlertSheet(
			AILocalizedString(@"Delete Dock Icon", nil), AILocalizedString(@"Delete", nil),
			AILocalizedString(@"Cancel", nil), @"", [self window], self,
			@selector(trashConfirmSheetDidEnd:returnCode:contextInfo:), nil, selectedIconPath,
			AILocalizedString(@"Are you sure you want to delete the %@ Dock Icon? It will be moved to the Trash.", nil),
			name);
	}
}

- (void)trashConfirmSheetDidEnd:(NSWindow *)sheet
					 returnCode:(NSInteger)returnCode
					contextInfo:(NSString *)selectedIconPath
{
	if (returnCode == NSOKButton) {
		NSInteger deletedIndex = [[[self imageCollectionView] selectionIndexes] firstIndex];

		// Deselect and stop animating
		[self setAnimatedDockIconAtIndex:NSNotFound];
		[[self imageCollectionView] setSelectionIndexes:[NSIndexSet indexSet]];

		// Trash the file & Rebuild our icons
		[[NSFileManager defaultManager] trashFileAtPath:selectedIconPath];
		[self xtrasChanged:nil];

		// Select the next available icon (prevent empty selection)
		NSUInteger newIndex = (deletedIndex == [[self icons] count]) ? --deletedIndex : deletedIndex;
		[[self imageCollectionView] setSelectionIndexes:[NSIndexSet indexSetWithIndex:newIndex]];
	}
}

@end
