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

#import <AIUtilities/AIArrayAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIToolbarUtilities.h>

#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIStatus.h>
#import <Adium/AIStatusIcons.h>
#import <Adium/AIToolbarControllerProtocol.h>

#import "AIStandardListWindowController.h"
#import "AIStatusController.h"

#import "AIContactController.h"
#import "AIContactListImagePicker.h"
#import "AIContactListNameButton.h"
#import "AIHoveringPopUpButton.h"

#define PREF_GROUP_APPEARANCE @"Appearance"

#define TOOLBAR_CONTACT_LIST @"ContactList:1.0" // Toolbar identifier

@interface AIStandardListWindowController ()
- (void)_configureToolbar;
- (void)updateStatusMenuSelection:(NSNotification *)notification;
- (void)updateImagePicker;
- (void)updateNameView;
- (void)repositionImagePickerToPosition:(ContactListImagePickerPosition)desiredImagePickerPosition;
- (void)listObjectAttributesChanged:(NSNotification *)inNotification;
@end

@implementation AIStandardListWindowController

/*!
 * @brief Deallocate
 */
- (void)dealloc
{}

	if ((!activeAccount && !
	}

	- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
	{
		return [NSArray arrayWithObject:@"StatusAndIcon"];
	}

	- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
	{
		return [NSArray arrayWithObject:@"StatusAndIcon"];
	}

	- (void)windowDidToggleToolbarShown:(NSWindow *)sender
	{
		[contactListController contactListDesiredSizeChanged];
	}

	- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
	{
		return [contactListController _desiredWindowFrameUsingDesiredWidth:YES desiredHeight:YES];
	}
	@end
