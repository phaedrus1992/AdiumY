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

#import "ESEventSoundAlertDetailPane.h"
#import "AIEventSoundsPlugin.h"
#import "AISoundController.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AILocalizationTextField.h>
#import <Adium/AISoundSet.h>

#define PLAY_A_SOUND AILocalizedString(@"Play a sound", nil)
#define KEY_DEFAULT_SOUND_DICT @"Default Sound Dict"

@interface ESEventSoundAlertDetailPane ()
- (NSMenu *)soundListMenu;
- (void)addSound:(NSString *)soundPath toMenu:(NSMenu *)soundMenu;
- (IBAction)selectSound:(id)sender;
@end

/*!
 * @class ESEventSoundAlertDetailPane
 * @brief Details pane for the Play Sound action
 */
@implementation ESEventSoundAlertDetailPane

/*!
 * @brief Nib name
 */
- (NSString *)nibName
{
	return @"EventSoundContactAlert";
}

/*!
 * @brief Configure the detail view
 */
- (void)viewDidLoad
{

	[menuItem setRepresentedObject:[soundPath stringByCollapsingBundlePath]];
	[menuItem setImage:soundFileIcon];
	[soundMenu addItem:menuItem];
}

/*!
 * @brief Add a soundPath to the menu root if it is not yet present, then select it
 *
 * @param The soundPath, which should have a collapsed bundle path (to match menuItem represented objects)
 */
- (void)addAndSelectSoundPath:(NSString *)soundPath
{
	NSMenu *rootMenu = [popUp_actionDetails menu];
	NSInteger menuIndex;

	// Check for it currently being present in the root menu
	menuIndex = [popUp_actionDetails indexOfItemWithRepresentedObject:soundPath];
	if (menuIndex == -1) {
		// Add it if it wasn't found
		[self addSound:soundPath toMenu:rootMenu];
		menuIndex = [popUp_actionDetails indexOfItemWithRepresentedObject:soundPath];
	}

	if (menuIndex != -1) {
		[popUp_actionDetails selectItemAtIndex:menuIndex];
	}
}

/*!
 * @brief A sound was selected from a sound popUp menu
 *
 * Update our header and play the sound.  If "Other..." is selected, allow selection of a file.
 */
- (IBAction)selectSound:(id)sender
{
	NSString *soundPath = [sender representedObject];

	if (soundPath != nil && [soundPath length] != 0) {
		[adium.soundController playSoundAtPath:[soundPath stringByExpandingBundlePath]]; // Play the sound

		// Update the menu and and the selection
		[self addAndSelectSoundPath:soundPath];

		[self detailsForHeaderChanged];
	} else { // selected "Other..."
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		openPanel.allowedFileTypes = [NSSound soundUnfilteredTypes]; // allow all the sounds NSSound understands
		[openPanel beginSheetModalForWindow:[view window]
						  completionHandler:^(NSInteger result) {
							  if (result == NSFileHandlingPanelOKButton) {
								  NSString *path = openPanel.URL.path;

								  [adium.soundController playSoundAtPath:path]; // Play the sound

								  // Update the menu and and the selection
								  [self addAndSelectSoundPath:[path stringByCollapsingBundlePath]];

								  [self detailsForHeaderChanged];
							  }
						  }];
	}
}

@end
