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

#import "AINewContactWindowController.h"
#import "AINewGroupWindowController.h"
#import "OWABSearchWindowController.h"
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIPopUpButtonAdditions.h>
#import <AIUtilities/AIStringAdditions.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIAddressBookController.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListGroup.h>
#import <Adium/AILocalizationTextField.h>
#import <Adium/AIService.h>
#import <Adium/AIServiceIcons.h>
#import <Adium/AIServiceMenu.h>
#import <Contacts/Contacts.h>

#define ADD_CONTACT_PROMPT_NIB @"AddContact"
#define DEFAULT_GROUP_NAME AILocalizedString(@"Contacts", nil)

@interface AINewContactWindowController ()
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)buildGroupMenu;
- (void)buildContactTypeMenu;
- (void)configureForCurrentServiceType;
- (void)ensureValidContactTypeSelection;
- (void)updateAccountList;
- (void)_setServiceType:(AIService *)inService;
- (IBAction)selectServiceType:(id)sender;

- (void)selectGroup:(id)sender;
- (void)newGroup:(id)sender;
- (void)newGroupDidEnd:(NSNotification *)inNotification;
- (void)accountListChanged:(NSNotification *)notification;

- (void)configureControlDimming;
@end

/*!
 * @class AINewContactWindowController
 * @brief Window controller for adding a new contact
 */
@implementation AINewContactWindowController

- (void)showOnWindow:(NSWindow *)parentWindow
{
	if (parentWindow) {

		checkedAccounts = [[NSMutableSet alloc] init];

		if (initialAccount && [accounts containsObject:initialAccount]) {
			// Select accounts by default
			[checkedAccounts addObject:initialAccount];

		} else if ([[accounts valueForKeyPath:@"@sum.online"] integerValue] == 1) {
			// Only one online account; it should be checked
			AIAccount *anAccount;

			for (anAccount in accounts) {
				if (anAccount.online) {
					[checkedAccounts addObject:anAccount];
					break;
				}
			}

		} else {
			// More than one online account; follow our 'add contact to' preferences
			AIAccount *anAccount;

			for (anAccount in accounts) {
				if ([[anAccount preferenceForKey:KEY_ADD_CONTACT_TO group:PREF_GROUP_ADD_CONTACT] boolValue])
					[checkedAccounts addObject:anAccount];
			}
		}

		[tableView_accounts reloadData];
	}

	-(void)configureControlDimming
	{
		BOOL shouldEnable = NO;

		if (([[textField_contactName stringValue] length] > 0)) {
			NSEnumerator *enumerator = [checkedAccounts objectEnumerator];
			AIAccount *account;
			while (!shouldEnable && (account = [enumerator nextObject]))
				if (account.contactListEditable)
					shouldEnable = YES;
		}

		[button_add setEnabled:shouldEnable];
	}

	/*!
	 * @brief Rows in the accounts table view
	 */
	-(NSInteger)numberOfRowsInTableView : (NSTableView *)tableView
	{
		return [accounts count];
	}

	/*!
	 * @brief Object value for columns in the accounts table view
	 */
	-(id)tableView : (NSTableView *)tableView objectValueForTableColumn : (NSTableColumn *)tableColumn row
		: (NSInteger)row
	{
		NSString *identifier = [tableColumn identifier];

		if ([identifier isEqualToString:@"check"]) {
			return ([[accounts objectAtIndex:row] contactListEditable]
						? [NSNumber numberWithBool:[checkedAccounts containsObject:[accounts objectAtIndex:row]]]
						: [NSNumber numberWithBool:NO]);

		} else if ([identifier isEqualToString:@"account"]) {
			return [[accounts objectAtIndex:row] explicitFormattedUID];

		} else {
			return @"";
		}
	}

	/*!
	 * @brief Will display cell
	 *
	 * Enable/disable account checkbox as appropriate
	 */
	-(void)tableView : (NSTableView *)tableView willDisplayCell : (id)cell forTableColumn
		: (NSTableColumn *)tableColumn row : (NSInteger)row
	{
		NSString *identifier = [tableColumn identifier];

		if ([identifier isEqualToString:@"check"]) {
			[cell setEnabled:[[accounts objectAtIndex:row] contactListEditable]];
		}
	}

	/*!
	 * @brief Set the enabled/disabled state for an account in the account list
	 */
	-(void)tableView : (NSTableView *)tableView setObjectValue : (id)object forTableColumn
		: (NSTableColumn *)tableColumn row : (NSInteger)row
	{
		NSString *identifier = [tableColumn identifier];

		if ([identifier isEqualToString:@"check"]) {
			[[accounts objectAtIndex:row] setPreference:[NSNumber numberWithBool:[object boolValue]]
												 forKey:KEY_ADD_CONTACT_TO
												  group:PREF_GROUP_ADD_CONTACT];
			if ([object boolValue]) {
				[checkedAccounts addObject:[accounts objectAtIndex:row]];
			} else {
				[checkedAccounts removeObject:[accounts objectAtIndex:row]];
			}

			[self configureControlDimming];
		}
	}

	/*!
	 * @brief Empty selector called by the group popUp menu
	 */
	-(void)selectGroup : (id)sender {}

	@end
