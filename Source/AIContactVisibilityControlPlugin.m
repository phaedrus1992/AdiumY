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

#import "AIContactVisibilityControlPlugin.h"
#import "AIContactController.h"
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIListGroup.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIMetaContact.h>

#define HIDE_CONTACTS_MENU_TITLE AILocalizedString(@"Hide Certain Contacts", nil)
#define HIDE_OFFLINE_MENU_TITLE AILocalizedString(@"Hide Offline Contacts", nil)
#define HIDE_IDLE_MENU_TITLE AILocalizedString(@"Hide Idle Contacts", nil)
#define HIDE_MOBILE_MENU_TITLE AILocalizedString(@"Hide Mobile Contacts", nil)
#define HIDE_BLOCKED_MENU_TITLE AILocalizedString(@"Hide Blocked Contacts", nil)
#define HIDE_ACCOUNT_CONTACT_MENU_TITLE AILocalizedString(@"Hide Contacts for Accounts", nil)
#define HIDE_AWAY_MENU_TITLE AILocalizedString(@"Hide Away Contacts", nil)
#define USE_OFFLINE_GROUP_MENU_TITLE AILocalizedString(@"Use Offline Group", nil)

@interface AIContactVisibilityControlPlugin ()
- (void)updateAccountMenu;
- (IBAction)toggleHide:(id)sender;
@end

/*!
 * @class AIContactVisibilityControlPlugin
 * @brief Component to handle showing or hiding offline contacts and hiding empty groups.
 *
 * Only manages menu items and preferences. The actaual hiding is done by their containing objects.
 */
@implementation AIContactVisibilityControlPlugin

/*!
 * @brief Install
 */
- (void)installPlugin
{
	// Default preferences

	menuItem_hideAway = nil;

forKey:
	KEY_HIDE_ACCOUNT_CONTACTS
group:PREF_GROUP_CONTACT_LIST_DISPLAY];
}

/*!
 * @brief Include all accounts.
 */
- (BOOL)accountMenu:(AIAccountMenu *)inAccountMenu shouldIncludeAccount:(AIAccount *)inAccount
{
	return YES;
}

/*!
 * @brief Update our account menu for current state information.
 */
- (void)updateAccountMenu
{
	for (NSMenuItem *menuItem in menu_hideAccounts.itemArray) {
		NSUInteger itemState = NSOffState;

		if ([array_hideAccounts containsObject:((AIAccount *)menuItem.representedObject).internalObjectID]) {
			itemState = NSOnState;
		}

		[menuItem setState:itemState];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem == menuItem_useOfflineGroup) {
		// Can only change the offline group preference if groups are enabled.
		return useContactListGroups;

	} else if (menuItem == menuItem_hideOffline || menuItem == menuItem_hideIdle || menuItem == menuItem_hideMobile ||
			   menuItem == menuItem_hideBlocked || menuItem == menuItem_hideAway ||
			   menuItem == menuItem_hideAccountContact) {
		return hideContacts;
	}

	return YES;
}
@end
