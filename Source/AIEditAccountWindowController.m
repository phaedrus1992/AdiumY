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

#import "AIEditAccountWindowController.h"
#import "AIAccountProxySettings.h"
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageViewWithImagePicker.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AITabViewAdditions.h>
#import <AIUtilities/AIViewAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIAccountViewController.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>

@interface AIEditAccountWindowController ()
- (void)_addCustomViewAndTabsForAccount:(AIAccount *)inAccount;
- (void)_addCustomView:(NSView *)customView
				   toView:(NSView *)setupView
	tabViewItemIdentifier:(NSString *)identifier
			runningHeight:(NSInteger *)height
					width:(NSInteger *)width;
- (void)_removeCustomViewAndTabs;
- (void)_localizeTabViewItemLabels;
- (void)saveConfiguration;
- (void)configureControlDimming;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
@end

/*!
 * @class AIEditAccountWindowController
 * @brief Window controller for configuring an <tt>AIAccount</tt>
 */
@implementation AIEditAccountWindowController

/*!
 * @brief Begin editing
 *
 * @param parentWindow A window on which to show the edit account window as a sheet.  If nil, account editing takes
 * place in an independent window.
 */
- (void)showOnWindow:(id)parentWindow
{
	if (parentWindow) {

		userIconData = imageData;

		if (!userIconData) {
			// If we got a nil user icon, that means the icon was deleted
			[self deleteInImageViewWithImagePicker:sender];
		}
	}

	-(NSString *)fileNameForImageInImagePicker : (AIImageViewWithImagePicker *)picker
	{
		NSString *fileName = [account.displayName safeFilenameString];
		if ([fileName hasPrefix:@"."]) {
			fileName = [fileName substringFromIndex:1];
		}
		return fileName;
	}

	-(NSImage *)emptyPictureImageForImageViewWithImagePicker : (AIImageViewWithImagePicker *)picker
	{
		return [AIServiceIcons serviceIconForObject:account type:AIServiceIconLarge direction:AIIconNormal];
	}

	@end
