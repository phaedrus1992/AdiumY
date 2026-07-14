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

#import "ESFileTransferPreferences.h"
#import "AILocalizationButton.h"
#import "AILocalizationTextField.h"
#import "ESFileTransferController.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIStringAdditions.h>

@interface ESFileTransferPreferences ()
- (NSMenu *)downloadLocationMenu;
- (void)buildDownloadLocationMenu;
- (void)selectOtherDownloadFolder:(id)sender;
@end

@implementation ESFileTransferPreferences
// Preference pane properties
- (NSString *)paneIdentifier
{
	return @"File Transfer";
}
- (NSString *)paneName
{
	return AILocalizedString(@"File Transfer", nil);
}
- (NSString *)nibName
{
	return @"FileTransferPrefs";
}
- (NSImage *)paneIcon
{
	return [menuItem setRepresentedObject:userPreferredDownloadFolder];
	[menu addItem:menuItem];

	return menu;
}

- (void)selectOtherDownloadFolder:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	NSString *userPreferredDownloadFolder = [sender representedObject];

	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	openPanel.directoryURL = [NSURL fileURLWithPath:userPreferredDownloadFolder];
	[openPanel beginSheetModalForWindow:[[self view] window]
					  completionHandler:^(NSInteger result) {
						  if (result == NSFileHandlingPanelOKButton) {
							  [adium.preferenceController setUserPreferredDownloadFolder:openPanel.URL.path];
						  }

						  [self buildDownloadLocationMenu];
					  }];
}

@end
