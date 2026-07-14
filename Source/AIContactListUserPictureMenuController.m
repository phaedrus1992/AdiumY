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

#import "AIContactListUserPictureMenuController.h"
#import "AIContactListImagePicker.h"
#import "AIStandardListWindowController.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIOSCompatibility.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>

#import <AIUtilities/IKRecentPicture.h> //10.5+, private

#pragma mark AIContactListUserPictureMenuController

@interface AIContactListUserPictureMenuController ()

- (id)initWithNibName:(NSString *)nibName imagePicker:(AIContactListImagePicker *)picker;

// IKRecentPicture related
- (NSArray *)recentPictures;
- (NSMutableArray *)recentSmallPictures;

// Menu actions
- (void)selectedAccount:(id)sender;
- (void)choosePicture:(id)sender;
- (void)clearRecentPictures:(id)sender;

@end

@implementation AIContactListUserPictureMenuController

@synthesize menu, imageCollectionView;
@synthesize imagePicker, images;

+ (void)popUpMenuForImagePicker:(AIContactListImagePicker *)picker
{}

#pragma mark - AIImageCollectionView delegate

- (BOOL)imageCollectionView:(AIImageCollectionView *)collectionView shouldHighlightItemAtIndex:(NSUInteger)anIndex
{
	return (anIndex < [[self recentPictures] count]);
}

- (BOOL)imageCollectionView:(AIImageCollectionView *)imageCollectionView shouldSelectItemAtIndex:(NSUInteger)anIndex
{
	return (anIndex < [[self recentPictures] count]);
}

- (void)imageCollectionView:(AIImageCollectionView *)imageCollectionView didSelectItemAtIndex:(NSUInteger)anIndex
{
	NSArray *recentPictures = [self recentPictures];

	if (anIndex < [recentPictures count]) {
		id recentPicture = [recentPictures objectAtIndex:anIndex];
		NSData *imageData = nil;

		/* XXX Check for and use the cropped image? */
		if ([recentPicture respondsToSelector:@selector(smallIcon)] && ([recentPicture smallIcon] != [NSNull null])) {
			imageData = [[recentPicture smallIcon] bestRepresentationByType];
		} else if ([recentPicture respondsToSelector:@selector(originalImagePath)]) {
			imageData = [NSData dataWithContentsOfFile:[recentPicture originalImagePath]];
		}

		// Notify as if the image had been selected in the picker
		[[[self imagePicker] delegate] imageViewWithImagePicker:imagePicker didChangeToImageData:imageData];

		// Now pass on the actual recent picture for use if possible
		[[self imagePicker] setRecentPictureAsImageInput:recentPicture];
	}

	[menu cancelTracking];
}

#pragma mark - Menu Actions

- (void)selectedAccount:(id)sender
{
	AIAccount *activeAccount = [sender representedObject];

	// Change the active account
	[adium.preferenceController setPreference:(activeAccount ? activeAccount.internalObjectID : nil)
									   forKey:@"Active Icon Selection Account"
										group:GROUP_ACCOUNT_STATUS];
}

- (void)choosePicture:(id)sender
{
	[imagePicker showImagePicker:nil];
}

- (void)clearRecentPictures:(id)sender
{
	[[IKPictureTakerRecentPictureRepository recentRepository] clearRecents:YES];
}

@end
