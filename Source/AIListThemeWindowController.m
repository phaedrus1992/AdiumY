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

#import "AIListThemeWindowController.h"
#import "AISCLViewPlugin.h"
#import "AITextColorPreviewView.h"
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIAbstractListController.h>
#import <Adium/AIListOutlineView.h>

@interface AIListThemeWindowController ()

- (void)configureControls;
- (void)configureControlDimming;
- (void)updateSliderValues;
- (void)configureBackgroundColoring;
- (NSMenu *)displayImageStyleMenu;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

@implementation AIListThemeWindowController

- (void)showOnWindow:(id)parentWindow
{
	if (parentWindow) {

		[menuItem setTag:AIFillStretchBackground];
		[displayImageStyleMenu addItem:menuItem];

		return displayImageStyleMenu;
	}

	@end
