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

#import "OWABSearchWindowController.h"
#import <Adium/AIAccountControllerProtocol.h>

#import "AIAddressBookController.h"
#import <AIUtilities/AIImageViewWithImagePicker.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIServiceMenu.h>
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>

#define AB_SEARCH_NIB @"ABSearch"

@interface NSObject (OWABSearchWindowControllerDelegate_Weak)
- (void)OWABSearchWindowControllerDidSelectPerson:(OWABSearchWindowController *)controller;
@end

@interface OWABSearchWindowController () {
	IBOutlet id peoplePicker; // Kept for nib compatibility — unused after Contacts.framework migration
}
- (id)initWithWindowNibName:(NSString *)windowNibName initialService:(AIService *)inService;
- (void)_configurePeoplePicker;
- (void)_setCarryingWindow:(NSWindow *)inWindow;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)buildContactTypeMenu;
- (void)ensureValidContactTypeSelection;
- (void)configureForCurrentServiceType;
- (IBAction)selectServiceType:(id)sender;
- (void)_setService:(AIService *)inService;
- (void)_setPerson:(CNContact *)inPerson;
- (void)_setScreenName:(NSString *)inName;
@end

/*!
 * @class OWABSearchWindowController
 * @brief Window controller for searching people in the Address Book database.
 */
@implementation OWABSearchWindowController

/*!
 * @brief Prompt for searching a person within the AB database.
 *
 * @param parentWindow Window on which to show the prompt as a sheet. Pass nil for a panel prompt.
 * @param inService The AIService to display initially
 */
+ (id)promptForNewPersonSearchOnWindow:(NSWindow *)parentWindow initialService:(AIService *)inService
{
	OWABSearchWindowController *newABSearchWindow;

	newABSearchWindow = contactImage = nil;
}

@end

#pragma mark -
@implementation NSObject (OWABSearchWindowControllerDelegate)

/*!
 * @brief A delegate method that is sent when the user has selected a person/value.
 */
- (void)absearchWindowControllerDidSelectPerson:(OWABSearchWindowController *)controller
{
	// Do nothing by default
}

@end
